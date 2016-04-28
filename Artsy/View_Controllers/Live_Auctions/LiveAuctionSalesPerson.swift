import Foundation
import Interstellar

/// Something to pretend to either be a network model or whatever
/// for now it can just parse the embedded json, and move it to obj-c when we're doing real networking

protocol LiveAuctionsSalesPersonType {
    var dataReadyForInitialDisplay: Observable<Void> { get }
    var currentLotSignal: Observable<LiveAuctionLotViewModelType> { get }

    var auctionViewModel: LiveAuctionViewModelType { get }
    var pageControllerDelegate: LiveAuctionPageControllerDelegate? { get }
    var lotCount: Int { get }
    var liveSaleID: String { get }

    func lotViewModelForIndex(index: Int) -> LiveAuctionLotViewModelType
    func lotViewModelRelativeToShowingIndex(offset: Int) -> LiveAuctionLotViewModelType?

    func bidOnLot(lot: LiveAuctionLotViewModelType)
    func leaveMaxBidOnLot(lot: LiveAuctionLotViewModel)
}

class LiveAuctionsSalesPerson:  NSObject, LiveAuctionsSalesPersonType {
    typealias StateManagerCreator = (host: String, causalitySaleID: String, accessToken: String) -> LiveAuctionStateManager

    let sale: LiveSale

    let dataReadyForInitialDisplay = Observable<Void>()
    let auctionViewModel: LiveAuctionViewModelType
    var pageControllerDelegate: LiveAuctionPageControllerDelegate?

    private(set) var lots = [LiveAuctionLotViewModelType]()
    private let stateManager: LiveAuctionStateManager

    // Lot currently being looked at by the user.
    var currentFocusedLotID = Observable<Int>()

    init(sale: LiveSale,
         accessToken: String,
         defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults(),
         stateManagerCreator: StateManagerCreator = LiveAuctionsSalesPerson.defaultStateManagerCreator()) {

        self.sale = sale
        self.auctionViewModel = LiveAuctionViewModel(sale: sale, currentLotID: nil)
        let host = defaults.stringForKey(ARStagingLiveAuctionSocketURLDefault) ?? "ws://localhost:8080"
        stateManager = stateManagerCreator(host: host, causalitySaleID: sale.causalitySaleID, accessToken: accessToken)

        super.init()

        pageControllerDelegate = LiveAuctionPageControllerDelegate(salesPerson: self)

        stateManager
            .newLotsSignal
            .subscribe { [weak self] lots -> Void in
                self?.lots = lots
                self?.dataReadyForInitialDisplay.update()
            }
    }
}

private typealias ComputedProperties = LiveAuctionsSalesPerson
extension ComputedProperties {
    var currentLotSignal: Observable<LiveAuctionLotViewModelType> {
        return stateManager.currentLotSignal
    }

    var updatedStateSignal: Observable<[LiveAuctionLotViewModelType]> {
        return stateManager.newLotsSignal
    }

    var lotCount: Int {
        return lots.count
    }

    var liveSaleID: String {
        return sale.liveSaleID
    }
}


private typealias PublicFunctions = LiveAuctionsSalesPerson
extension LiveAuctionsSalesPerson {

    // Returns nil if there is no current lot.
    func lotViewModelRelativeToShowingIndex(offset: Int) -> LiveAuctionLotViewModelType? {
        guard let currentlyShowingIndex = currentFocusedLotID.peek() else { return nil }
        let newIndex = currentlyShowingIndex + offset
        let loopingIndex = newIndex > 0 ? newIndex : lots.count + offset
        return lotViewModelForIndex(loopingIndex)
    }

    func lotViewModelForIndex(index: Int) -> LiveAuctionLotViewModelType {
        return lots[index]
    }

    func bidOnLot(lot: LiveAuctionLotViewModelType) {
        stateManager.bidOnLot("") // TODO: Extract lot ID once https://github.com/artsy/eigen/pull/1386 is merged.
    }

    func leaveMaxBidOnLot(lot: LiveAuctionLotViewModel) {
        stateManager.bidOnLot("") // TODO: Extract lot ID once https://github.com/artsy/eigen/pull/1386 is merged.
    }
}

private typealias ClassMethods = LiveAuctionsSalesPerson
extension ClassMethods {

    class func defaultStateManagerCreator() -> StateManagerCreator {
        return { host, causalitySaleID, accessToken in
            LiveAuctionStateManager(host: host, causalitySaleID: causalitySaleID, accessToken: accessToken)
        }
    }

    class func stubbedStateManagerCreator() -> StateManagerCreator {
        return { host, causalitySaleID, accessToken in
            // TODO: stub the socket communicator.
            LiveAuctionStateManager(host: host, causalitySaleID: causalitySaleID, accessToken: accessToken)
        }
    }

}


class LiveAuctionPageControllerDelegate: NSObject, UIPageViewControllerDelegate {
    let salesPerson: LiveAuctionsSalesPerson

    init(salesPerson: LiveAuctionsSalesPerson) {
        self.salesPerson = salesPerson
    }

    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

        guard let viewController = pageViewController.viewControllers?.first as? LiveAuctionLotViewController else { return }
        salesPerson.currentFocusedLotID.update(viewController.index)
    }
}

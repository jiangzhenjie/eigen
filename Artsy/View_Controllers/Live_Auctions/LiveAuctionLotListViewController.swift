import UIKit
import Interstellar


protocol LiveAuctionLotListViewControllerDelegate: class {
    func didSelectLotAtIndex(index: Int, forLotListViewController lotListViewController: LiveAuctionLotListViewController)
}

class LiveAuctionLotListViewController: UICollectionViewController {
    let salesPerson: LiveAuctionsSalesPersonType
    let currentLotSignal: Observable<LiveAuctionLotViewModelType>
    let stickyCollectionViewLayout: LiveAuctionLotListStickyCellCollectionViewLayout
    let auctionViewModel: LiveAuctionViewModelType

    var observerToken: ObserverToken?

    var selectedIndex: Int = 0 {
        didSet {
            let path = NSIndexPath(forRow: selectedIndex, inSection: 0)
            collectionView?.selectItemAtIndexPath(path, animated: false, scrollPosition: .None)
        }
    }

    weak var delegate: LiveAuctionLotListViewControllerDelegate?

    private var currentLotSignalObserver: ObserverToken!

    init(salesPerson: LiveAuctionsSalesPersonType, currentLotSignal: Observable<LiveAuctionLotViewModelType>, auctionViewModel: LiveAuctionViewModelType) {
        self.salesPerson = salesPerson
        self.currentLotSignal = currentLotSignal
        self.stickyCollectionViewLayout = LiveAuctionLotListStickyCellCollectionViewLayout()
        self.auctionViewModel = auctionViewModel

        super.init(collectionViewLayout: self.stickyCollectionViewLayout)

        currentLotSignalObserver = currentLotSignal.subscribe { [weak self] lot in
            self?.stickyCollectionViewLayout.setActiveIndex(lot.lotIndex)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    deinit {
        currentLotSignal.unsubscribe(currentLotSignalObserver)
        if let observerToken = observerToken {
            salesPerson.dataReadyForInitialDisplay.unsubscribe(observerToken)
        }
    }

    override func viewDidLoad() {
        collectionView?.backgroundColor = .whiteColor()
        title = "Lots"

        collectionView?.registerClass(LotListCollectionViewCell.self, forCellWithReuseIdentifier: LotListCollectionViewCell.CellIdentifier)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if observerToken != nil {
            observerToken = salesPerson.dataReadyForInitialDisplay.subscribe { [weak self] _ in
                self?.collectionView?.reloadData()
            }
        }
    }

    func lotAtIndexPath(indexPath: NSIndexPath) -> LiveAuctionLotViewModelType {
        return salesPerson.lotViewModelForIndex(indexPath.item)
    }
}

private typealias CollectionView = LiveAuctionLotListViewController
extension CollectionView {
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return salesPerson.lotCount
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(LotListCollectionViewCell.CellIdentifier, forIndexPath: indexPath)

        let viewModel = lotAtIndexPath(indexPath)
        (cell as? LotListCollectionViewCell)?.configureForViewModel(viewModel, auctionViewModel: auctionViewModel, indexPath: indexPath)

        cell.selected = indexPath.row == selectedIndex
        return cell
    }

    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let oldSelectedIndex = NSIndexPath(forRow: selectedIndex, inSection: 0)
        collectionView.deselectItemAtIndexPath(oldSelectedIndex, animated: true)

        selectedIndex = indexPath.row
        delegate?.didSelectLotAtIndex(indexPath.item, forLotListViewController: self)
    }
}



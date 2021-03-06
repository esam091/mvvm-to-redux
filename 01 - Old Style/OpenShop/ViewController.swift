//
//  ViewController.swift
//  OpenShopRedux
//
//  Created by Samuel Edwin on 07/01/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import UIKit
import RxCocoa
import NSObject_Rx
import RxSwift

class ViewController: UIViewController {
    @IBOutlet var shopNameField: UITextField!
    @IBOutlet var shopNameLabel: UILabel!
    
    @IBOutlet var shopDomainField: UITextField!
    @IBOutlet var shopDomainLabel: UILabel!
    
    @IBOutlet var cityButton: UIButton!
    @IBOutlet var cityLabel: UILabel!
    
    @IBOutlet var districtLabel: UILabel!
    @IBOutlet var districtButton: UIButton!
    
    @IBOutlet var createShopButton: UIButton!
    
    var viewModel: ViewModel 
    
    required init?(coder: NSCoder) {
        var useCase = UseCase.mock
        
//        useCase.checkShopName = { name in
//            Driver.just(ValidateShopNameResponse(suggestedDomain: "something random", shopNameErrorMessage: "shop name already taken"))
//                .delay(.seconds(2))
//
//        }
        
        useCase.submit = { _ in
            Driver.just(.success(())).delay(.seconds(1))
        }
        
        viewModel = ViewModel(useCase: useCase)
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let citySelection = cityButton.rx.tap.asDriver().map { _ -> CityViewController in
            let vc = CityViewController()
            self.present(vc, animated: true, completion: nil)
            
            return vc
        }
        
        let cityDidSelected = citySelection.flatMap { $0.selectedCity2 }
        let citySelectionDismissed = citySelection.flatMap { $0.dismissed }
        
        let showDistrictSelection = PublishSubject<Void>()
        
        let districtSelection = showDistrictSelection.asDriver(onErrorDriveWith: .empty()).map { _ -> DistrictViewController in
            let vc = DistrictViewController()
            self.present(vc, animated: true, completion: nil)
            
            return vc
        }
        let districtDidSelected = districtSelection.flatMap { $0.selectedDistrict }
        let districtDidDismissed = districtSelection.flatMap { $0.closed }
        
        let input = ViewModel.Input(
            shopNameDidChange: shopNameField.rx.textChanged.asDriver(onErrorDriveWith: .empty()),
            shopDomainDidChange: shopDomainField.rx.textChanged.asDriver(onErrorDriveWith: .empty()),
            cityDidSelected: cityDidSelected,
            cityDidDismissed: citySelectionDismissed,
            districtDidTapped: districtButton.rx.tap.asDriver(),
            districtDidSelected: districtDidSelected,
            districtDidDismissed: districtDidDismissed,
            submitButtonDidTap: createShopButton.rx.tap.asDriver()
        )
        
        let output = viewModel.transform(input)
        
        output.showDistrictSelection.drive(showDistrictSelection).disposed(by: rx.disposeBag)
        
        output.domainName.drive(shopDomainField.rx.text).disposed(by: rx.disposeBag)
        output.shopNameError.drive(shopNameLabel.rx.text).disposed(by: rx.disposeBag)
        output.domainNameError.drive(shopDomainLabel.rx.text).disposed(by: rx.disposeBag)
        
        output.selectedCity.map { $0.name }.drive(cityButton.rx.title(for: .normal)).disposed(by: rx.disposeBag)
        
        output.selectedDistrict.map { $0.name }.drive(districtButton.rx.title(for: .normal)).disposed(by: rx.disposeBag)
        
        output.citySelectionError
            .map { err in err != nil ? "Please select city" : "" }
            .drive(cityLabel.rx.text).disposed(by: rx.disposeBag)
        
        output.districtSelectioonError.map { err in
            switch err {
            case .dismissed: return "no district selected"
            case .noCitySelected: return "please select a city first"
            default: return ""
            }
        }.drive(districtLabel.rx.text).disposed(by: rx.disposeBag)
        
        output.submissionResult.drive(onNext: { [weak self] result in
            let message: String
            
            switch result {
            case .success: message = "Success"
            case let .failure(error): message = error.message
            }
            
            let alert = UIAlertController(title: "Result", message: message, preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            self?.present(alert, animated: false, completion: nil)
        }).disposed(by: rx.disposeBag)
    }


}




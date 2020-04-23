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
import CasePaths

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
    
    
    let store: Store<State, Action, UseCase>
    
    
    required init?(coder: NSCoder) {
        let useCase = UseCase.mock
        
        useCase.checkShopName = { name in
            Driver.just(ValidateShopNameResponse(suggestedDomain: "something random", shopNameErrorMessage: nil))
                .delay(.seconds(2))

        }
        
        useCase.checkDomainName = { name in
//            Driver.just(.failure(SimpleErrorMessage(message: "\(name) already taken"))).delay(.seconds(1))
            Driver.just(.success(())).delay(.seconds(1))
        }
        
        useCase.submit = { _ in
            Driver.just(.success(Unit())).delay(.seconds(1))
        }
        
        store = Store(initialValue: State(), reducer: reducer, environment: useCase)
        
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
        
        
        Driver.merge(
            shopNameField
                .rx.textChanged
                .asDriver(onErrorDriveWith: .empty())
                .map(Action.shopNameDidChange),
            
            shopDomainField.rx.textChanged.asDriver(onErrorDriveWith: .empty())
                .map(Action.shopDomainDidChange),
            
            cityDidSelected
                .map(Action.cityDidSelected),
            
            citySelectionDismissed
                .map { Action.cityDidDismissed },
            
            districtButton.rx.tap.asDriver()
                .map { Action.districtDidTapped },
            
            districtDidSelected
                .map(Action.districtDidSelected),
            
            districtDidDismissed
                .map { Action.districtDidDismissed },
            
            createShopButton.rx.tap.asDriver()
                .map { Action.submitButtonDidTap }
        ).drive(onNext: {[weak self] action in
            self?.store.send(action)
        }).disposed(by: rx.disposeBag)
        
        store.subscribeAction(/Action.showDistrictSelection).drive(showDistrictSelection).disposed(by: rx.disposeBag)
        
        
        store.subscribe(\.selectedDomainName)
            .drive(shopDomainField.rx.text)
            .disposed(by: rx.disposeBag)

        store.subscribe(\.shopNameErrorMessage)
            .drive(shopNameLabel.rx.text).disposed(by: rx.disposeBag)
        
        
        
        store.subscribe(\.domainErrorMessage)
            .drive(shopDomainLabel.rx.text).disposed(by: rx.disposeBag)
        
        
        store.subscribe(\.city?.name)
            .compactMap { $0 }
            .drive(cityButton.rx.title(for: .normal)).disposed(by: rx.disposeBag)
        
        
        store.subscribe(\.district?.name)
            .compactMap { $0 }
            .drive(districtButton.rx.title(for: .normal)).disposed(by: rx.disposeBag)
        
        
        store.subscribe(\.cityError)
            .map { err in err != nil ? "Please select city" : "" }
            .drive(cityLabel.rx.text).disposed(by: rx.disposeBag)
        
        
        store
            .subscribe(\.districtError)
            .map ({ err -> String in
                switch err {
                case .dismissed: return "no district selected"
                case .noCitySelected: return "please select a city first"
                default: return ""
                }})
                .drive(districtLabel.rx.text)
                .disposed(by: rx.disposeBag)
        
        
        store.subscribeAction(/Action.submissionResult).drive(onNext: { [weak self] result in
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




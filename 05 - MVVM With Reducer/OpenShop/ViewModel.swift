//
//  ViewModel.swift
//  OpenShop
//
//  Created by Samuel Edwin on 19/04/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay
import RxCocoa
import CasePaths


enum OpenShopInput {
    case shopNameDidChange(String)
    case shopDomainDidChange(String)
    case cityDidSelected(City)
    case cityDidDismissed
    case districtDidTapped
    case districtDidSelected(District)
    case districtDidDismissed
    case submitButtonDidTap
    
    case didValidateShopName(ValidateShopNameResponse)
}

struct State: Equatable {
    var shopName: String?
    var shopNameErrorMessage: String?
    
    var selectedDomainName: String?
    var domainErrorMessage: String?
    
    var city: City?
    var cityError: CitySelectionError?
    
    var district: District?
    var districtError: DistrictSelectionError?
}

func reducer(state: inout State, action: OpenShopInput, environment: UseCase) -> [Driver<OpenShopInput>] {
    switch action {
    case let .shopNameDidChange(shopName):
        state.shopName = shopName
        
        return [ environment.checkShopName(shopName).map(OpenShopInput.didValidateShopName) ]
    
    case let .didValidateShopName(response):
        state.shopNameErrorMessage = response.shopNameErrorMessage
        state.selectedDomainName = response.suggestedDomain
        
        return []
        
    default: return []
    }
}

class ViewModel {
    struct Output {
        let showDistrictSelection: Driver<Void>
        let submissionResult: Driver<Result<Void, SimpleErrorMessage>>
        let state: Driver<State>
    }
    
    private let useCase: UseCase
    private let disposeBag = DisposeBag()
    
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    
    func transform(_ input: Driver<OpenShopInput>) -> Output {
        let useCase = self.useCase
        
        var state = State()
        
        let subject = PublishSubject<OpenShopInput>()
        
        input.drive(subject).disposed(by: disposeBag)
        
        subject.asDriver(onErrorDriveWith: .empty()).flatMap { action -> Driver<OpenShopInput> in
            let effect = reducer(state: &state, action: action, environment: useCase)
            return Driver.from(effect).merge()
        }
        .drive(subject).disposed(by: disposeBag)
        
        let stateOutput = subject
            .asDriver(onErrorDriveWith: .empty())
            .debug("action")
            .map { _ in state }
        
        return Output(
            showDistrictSelection: .empty(),
            submissionResult: .empty(),
            
            state: stateOutput
        )
    }
}

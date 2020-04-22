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


enum Action {
    case shopNameDidChange(String)
    case shopDomainDidChange(String)
    case cityDidSelected(City)
    case cityDidDismissed
    case districtDidTapped
    case districtDidSelected(District)
    case districtDidDismissed
    case submitButtonDidTap
    
    case didValidateShopName(ValidateShopNameResponse)
    case domainNameError(String)
    case showDistrictSelection
    case submissionResult(Result<Void, SimpleErrorMessage>)
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

func reducer(state: inout State, action: Action, environment: UseCase) -> [Driver<Action>] {
    switch action {
    case let .shopNameDidChange(shopName):
        state.shopName = shopName
        state.shopNameErrorMessage = nil
        
        return [ environment.checkShopName(shopName).map(Action.didValidateShopName) ]
    
    case let .didValidateShopName(response):
        state.shopNameErrorMessage = response.shopNameErrorMessage
        state.selectedDomainName = response.suggestedDomain
        
        return []
        
    case let .shopDomainDidChange(domainName):
        state.selectedDomainName = domainName
        state.domainErrorMessage = nil
        
        return [
            environment.checkDomainName(domainName).flatMap { result -> Driver<Action> in
                switch result {
                case .success: return .empty()
                case let .failure(error): return .just(.domainNameError(error.message))
                }
            }
        ]
        
    case let .domainNameError(message):
        state.domainErrorMessage = message
        return []
        
    case let .cityDidSelected(city):
        state.city = city
        state.cityError = nil
        return []
        
    case .cityDidDismissed:
        if state.city == nil {
            state.cityError = . dismissed
        }
        
        return []
        
    case .districtDidTapped:
        if state.city == nil {
            state.districtError = .noCitySelected
            return []
        } else {
            return [.just(.showDistrictSelection)]
        }
        
    case .districtDidDismissed:
        if state.district == nil {
            state.districtError = .dismissed
        }
        return []
        
    case let .districtDidSelected(district):
        state.district = district
        state.districtError = nil
        return []
        
    case .submitButtonDidTap:
        guard let shopName = state.shopName,
            let domainName = state.selectedDomainName,
            let city = state.city,
            let district = state.district,
            state.shopNameErrorMessage == nil && state.domainErrorMessage == nil && state.cityError == nil && state.districtError == nil else {
                return []
        }
        
        return [
            environment.submit(Form(domainName: domainName, shopName: shopName, cityID: city.id, districtID: district.id))
                .map(Action.submissionResult)
        ]
        
    default: return []
    }
}

class ViewModel {
    struct Output {
        let submissionResult: Driver<Result<Void, SimpleErrorMessage>>
        let action: Driver<Action>
        let state: Driver<State>
    }
    
    private let useCase: UseCase
    private let disposeBag = DisposeBag()
    
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    
    func transform(_ input: Driver<Action>) -> Output {
        let useCase = self.useCase
        
        var state = State()
        
        let subject = PublishSubject<Action>()
        
        input.drive(subject).disposed(by: disposeBag)
        
        subject.asDriver(onErrorDriveWith: .empty()).flatMap { action -> Driver<Action> in
            let effect = reducer(state: &state, action: action, environment: useCase)
            return Driver.from(effect).merge()
        }
        .drive(subject).disposed(by: disposeBag)
        
        let stateOutput = subject
            .asDriver(onErrorDriveWith: .empty())
            .debug("action")
            .map { _ in state }
            .debug("state")
        
        return Output(
            submissionResult: .empty(),
            
            action: subject.asDriver(onErrorDriveWith: .empty()),
            state: stateOutput
        )
    }
}

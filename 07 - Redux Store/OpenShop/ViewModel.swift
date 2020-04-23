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

// Void is an empty tuple, and tuples cannot be Equatables. Think of Unit as an Equatable version of void
struct Unit: Equatable {}

enum Action: Equatable {
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
    case submissionResult(Result<Unit, SimpleErrorMessage>)
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

typealias Reducer<State, Action, Environment> = (inout State, Action, Environment) -> [Driver<Action>]

class Store<State: Equatable, Action, Environment> {
    private(set) var state: State
    private let reducer: Reducer<State, Action, Environment>
    private let environment: Environment
    
    private let disposeBag = DisposeBag()
    private let subject = PublishSubject<State>()
    private let actionSubject = PublishSubject<Action>()
    
    init(
        initialValue: State,
        reducer: @escaping Reducer<State, Action, Environment>,
        environment: Environment
    ) {
        self.state = initialValue
        self.reducer = reducer
        self.environment = environment
    }
    
    func send(_ action: Action) {
        actionSubject.onNext(action)
        let effects = reducer(&state, action, environment)
        subject.onNext(state)
        
        effects.forEach { (effect) in
            effect.drive(onNext: { [weak self] action in
                self?.send(action)
            }).disposed(by: disposeBag)
        }
    }
    
    func subscribe<SubState: Equatable>(_ keyPath: KeyPath<State, SubState>) -> Driver<SubState> {
        subject.asDriver(onErrorDriveWith: .empty())
            .map { $0[keyPath: keyPath] }
            .distinctUntilChanged()
    }
    
    func subscribeAction<SubAction>(_ casePath: CasePath<Action, SubAction>) -> Driver<SubAction> {
        actionSubject
            .asDriver(onErrorDriveWith: .empty())
            .compactMap(casePath.extract(from:))
    }
}

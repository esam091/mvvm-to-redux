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

class ViewModel {
    struct Output {
        let showDistrictSelection: Driver<Void>
        let submissionResult: Driver<Result<Void, SimpleErrorMessage>>
        let state: Driver<State>
    }
    
    private let useCase: UseCase
    
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    
    func transform(_ input: Driver<OpenShopInput>) -> Output {
        let useCase = self.useCase
        
        var state = State()
        
        let shopNameDidChange = input.compactMap(/OpenShopInput.shopNameDidChange)
        let shopDomainDidChange = input.compactMap(/OpenShopInput.shopDomainDidChange)
        let cityDidSelected = input.compactMap(/OpenShopInput.cityDidSelected)
        let cityDidDismissed = input.compactMap(/OpenShopInput.cityDidDismissed)
        let districtDidSelected = input.compactMap(/OpenShopInput.districtDidSelected)
        let districtDidDismissed = input.compactMap(/OpenShopInput.districtDidDismissed)
        let districtDidTapped = input.compactMap(/OpenShopInput.districtDidTapped)
        let submitButtonDidTap = input.compactMap(/OpenShopInput.submitButtonDidTap)
        
        let inputShopName = shopNameDidChange.do(onNext: { state.shopName = $0 })
        let shopDomain = shopDomainDidChange.do(onNext: { state.selectedDomainName = $0 })
        
        let shopNameCheck = inputShopName
            .flatMapLatest {
                useCase.checkShopName($0)
        }
        
        let domainSuggestion = shopNameCheck.map { $0.suggestedDomain }.do(onNext: { state.selectedDomainName = $0 })
        
        let shopNameError = Driver<String?>.merge(
            shopNameCheck.map { $0.shopNameErrorMessage }.filter {
                $0 != nil
            }.map { $0! },
            
            inputShopName.map { _ in nil }
        )
            .do(onNext: { state.shopNameErrorMessage = $0 })
        
        let domainCheck = shopDomain.flatMap { domain in
            useCase.checkDomainName(domain)
        }
        
        let _shopDomainError = Driver<String?>.merge(
            shopDomain.map { _ in nil },
            domainCheck.success.map { nil },
            domainCheck.failure.map { $0.message }
        ).do(onNext: { state.domainErrorMessage = $0 })
        
        let _selectCityFail = Driver.merge(
            cityDidDismissed.filter { _ in state.city == nil } .map { CitySelectionError.dismissed },
            cityDidSelected.map { _ -> CitySelectionError? in nil  }
        ).do(onNext: { state.cityError = $0 })
        
        
        let _selectCitySuccess = cityDidSelected
            .do(onNext: { state.city = $0 })
        
        let selectedDistrict = districtDidSelected
            .do(onNext: { state.district = $0 })
        
        let districtFailure = Driver<DistrictSelectionError?>.merge(
            districtDidDismissed.filter { _ in state.district == nil }.map { _ in DistrictSelectionError.dismissed },
            districtDidTapped.filter { _ in state.city == nil }.map { _ in DistrictSelectionError.noCitySelected },
            districtDidTapped.filter { _ in state.city != nil }.map { _ in nil }
        ).do(onNext: { state.districtError = $0 })
        
        let showDistrictSelection = districtDidTapped
            .filter { _ in state.city != nil }
            .map { () }
        
        let submissionResult = submitButtonDidTap
            .filter {
                state.shopName != nil
                    && state.shopNameErrorMessage == nil
                    && state.selectedDomainName != nil
                    && state.domainErrorMessage == nil
                    && state.city != nil
                    && state.cityError == nil
                    && state.district != nil
                    && state.districtError == nil
        }
        .map { _ in
            Form(domainName: state.selectedDomainName!, shopName: state.shopName!, cityID: state.city!.id, districtID: state.district!.id)
        }.flatMap {
            useCase.submit($0)
        }
            
        
        return Output(
            showDistrictSelection: showDistrictSelection,
            submissionResult: submissionResult,
            
            state: Driver.merge(
                shopNameError.map { _ in state },
                domainSuggestion.map { _ in state },
                _shopDomainError.map { _ in state },
                _selectCitySuccess.map { _ in state },
                _selectCityFail.map { _ in state },
                selectedDistrict.map { _ in state },
                districtFailure.map { _ in state }
            )
        )
    }
}

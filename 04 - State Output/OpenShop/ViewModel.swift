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

class ViewModel {
    struct Output {
        let shopNameError: Driver<String?>
        let domainName: Driver<String>
        let domainNameError: Driver<String?>
        
        let selectedCity: Driver<City>
        let citySelectionError: Driver<CitySelectionError?>
        let selectedDistrict: Driver<District>
        let districtSelectioonError: Driver<DistrictSelectionError?>
        let showDistrictSelection: Driver<Void>
        let submissionResult: Driver<Result<Void, SimpleErrorMessage>>
    }
    
    private let useCase: UseCase
    
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    
    func transform(_ input: Driver<OpenShopInput>) -> Output {
        let useCase = self.useCase
        
        var shopName: String?
        var shopNameErrorMessage: String?
        
        var selectedDomainName: String?
        var domainErrorMessage: String?
        
        var city: City?
        var cityError: CitySelectionError?
        
        var district: District?
        var districtError: DistrictSelectionError?
        
        let shopNameDidChange = input.compactMap(/OpenShopInput.shopNameDidChange)
        let shopDomainDidChange = input.compactMap(/OpenShopInput.shopDomainDidChange)
        let cityDidSelected = input.compactMap(/OpenShopInput.cityDidSelected)
        let cityDidDismissed = input.compactMap(/OpenShopInput.cityDidDismissed)
        let districtDidSelected = input.compactMap(/OpenShopInput.districtDidSelected)
        let districtDidDismissed = input.compactMap(/OpenShopInput.districtDidDismissed)
        let districtDidTapped = input.compactMap(/OpenShopInput.districtDidTapped)
        let submitButtonDidTap = input.compactMap(/OpenShopInput.submitButtonDidTap)
        
        let inputShopName = shopNameDidChange.do(onNext: { shopName = $0 })
        let shopDomain = shopDomainDidChange.do(onNext: { selectedDomainName = $0 })
        
        let shopNameCheck = inputShopName
            .flatMapLatest {
                useCase.checkShopName($0)
        }
        
        let domainSuggestion = shopNameCheck.map { $0.suggestedDomain }.do(onNext: { selectedDomainName = $0 })
        
        let shopNameError = Driver<String?>.merge(
            shopNameCheck.map { $0.shopNameErrorMessage }.filter {
                $0 != nil
            }.map { $0! },
            
            inputShopName.map { _ in nil }
        )
            .do(onNext: { shopNameErrorMessage = $0 })
        
        let domainCheck = shopDomain.flatMap { domain in
            useCase.checkDomainName(domain)
        }
        
        let _shopDomainError = Driver<String?>.merge(
            shopDomain.map { _ in nil },
            domainCheck.success.map { nil },
            domainCheck.failure.map { $0.message }
        ).do(onNext: { domainErrorMessage = $0 })
        
        let _selectCityFail = Driver.merge(
            cityDidDismissed.filter { _ in city == nil } .map { CitySelectionError.dismissed },
            cityDidSelected.map { _ -> CitySelectionError? in nil  }
        ).do(onNext: { cityError = $0 })
        
        
        let _selectCitySuccess = cityDidSelected
            .do(onNext: { city = $0 })
        
        let selectedDistrict = districtDidSelected
            .do(onNext: { district = $0 })
        
        let districtFailure = Driver<DistrictSelectionError?>.merge(
            districtDidDismissed.filter { _ in district == nil }.map { _ in DistrictSelectionError.dismissed },
            districtDidTapped.filter { _ in city == nil }.map { _ in DistrictSelectionError.noCitySelected },
            districtDidTapped.filter { _ in city != nil }.map { _ in nil }
        ).do(onNext: { districtError = $0 })
        
        let showDistrictSelection = districtDidTapped
            .filter { _ in city != nil }
            .map { () }
        
        let submissionResult = submitButtonDidTap
            .filter {
                shopName != nil
                    && shopNameErrorMessage == nil
                    && selectedDomainName != nil
                    && domainErrorMessage == nil
                    && city != nil
                    && cityError == nil
                    && district != nil
                    && districtError == nil
        }
        .map { _ in
            Form(domainName: selectedDomainName!, shopName: shopName!, cityID: city!.id, districtID: district!.id)
        }.flatMap {
            useCase.submit($0)
        }
            
        
        return Output(
            shopNameError: shopNameError,
            domainName: domainSuggestion,
        
            domainNameError: _shopDomainError,
            
            selectedCity: _selectCitySuccess,
            citySelectionError: _selectCityFail,
            selectedDistrict: selectedDistrict,
            
            districtSelectioonError: districtFailure,
            showDistrictSelection: showDistrictSelection,
            submissionResult: submissionResult
        )
    }
}

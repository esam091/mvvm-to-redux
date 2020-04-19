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

class ViewModel {
    struct Input {
        let shopNameDidChange: Driver<String>
        let shopDomainDidChange: Driver<String>
        let cityDidSelected: Driver<City>
        let cityDidDismissed: Driver<Void>
        let districtDidTapped: Driver<Void>
        let districtDidSelected: Driver<District>
        let districtDidDismissed: Driver<Void>
        let submitButtonDidTap: Driver<Void>
    }
    
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
    
    
    func transform(_ input: Input) -> Output {
        let useCase = self.useCase
        
        var shopName: String?
        var shopNameErrorMessage: String?
        
        var selectedDomainName: String?
        var domainErrorMessage: String?
        
        var city: City?
        var cityError: CitySelectionError?
        
        var district: District?
        var districtError: DistrictSelectionError?
        
        let inputShopName = input.shopNameDidChange.do(onNext: { shopName = $0 })
        let shopDomain = input.shopDomainDidChange.do(onNext: { selectedDomainName = $0 })
        
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
            input.cityDidDismissed.filter { _ in city == nil } .map { CitySelectionError.dismissed },
            input.cityDidSelected.map { _ -> CitySelectionError? in nil  }
        ).do(onNext: { cityError = $0 })
        
        
        let _selectCitySuccess = input.cityDidSelected
            .do(onNext: { city = $0 })
        
        let selectedDistrict = input.districtDidSelected
            .do(onNext: { district = $0 })
        
        let districtFailure = Driver<DistrictSelectionError?>.merge(
            input.districtDidDismissed.filter { _ in district == nil }.map { _ in DistrictSelectionError.dismissed },
            input.districtDidTapped.filter { _ in city == nil }.map { _ in DistrictSelectionError.noCitySelected },
            input.districtDidTapped.filter { _ in city != nil }.map { _ in nil }
        ).do(onNext: { districtError = $0 })
        
        let showDistrictSelection = input.districtDidTapped
            .filter { _ in city != nil }
            .map { () }
        
        let submissionResult = input.submitButtonDidTap
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

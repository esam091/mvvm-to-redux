//
//  OpenShopTests.swift
//  OpenShopTests
//
//  Created by Samuel Edwin on 19/04/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import XCTest
@testable import OpenShop
import RxSwift
import RxCocoa



class OpenShopTests: XCTestCase {
    
    func test_inputShowName_showDomainSuggestion() {
        var useCase = UseCase.mock
        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))
        }
        
        let disposeBag = DisposeBag()

        var state = State()
        var effects = reducer(state: &state, action: .shopNameDidChange("something"), environment: useCase)
        
        XCTAssertEqual(state, State(shopName: "something"))
        XCTAssertEqual(effects.count, 1)
        
        var action: Action!
        effects[0].drive(onNext: {
            action = $0
        }).disposed(by: disposeBag)
        
        effects = reducer(state: &state, action: action, environment: useCase)
        XCTAssertEqual(effects.count, 0)
        
        XCTAssertEqual(state, State(shopName: "something", selectedDomainName: "foo"))
        
//        input.onNext(.shopNameDidChange("something"))
//
//        state.assertLastValue(State(shopName: "something", selectedDomainName: "foo"))
    }

//    func test_inputShopName_showDomainSuggestionWithErrors() {
//        let called = expectation(description: "use case called")
//
//        useCase.checkShopName = { _ in
//            Driver.just(ValidateShopNameResponse(suggestedDomain: "bar", shopNameErrorMessage: "error message"))
//                .delay(.nanoseconds(1))
//                .do(onNext: { _ in called.fulfill() })
//        }
//
//        input.onNext(.shopNameDidChange("another thing"))
//        state.assertLastValue(State(shopName: "another thing"))
//
//        wait(for: [called], timeout: 0.001)
//
//
//        state.assertLastValue(State(shopName: "another thing", shopNameErrorMessage: "error message", selectedDomainName: "bar"))
//    }
//
//    func test_inputDomainName_valid() {
//        useCase.checkDomainName = { _ in
//            .just(.success(()))
//        }
//
//        input.onNext(.shopDomainDidChange("foo"))
//
//        state.assertLastValue(State(selectedDomainName: "foo"))
//    }
//
//    func test_inputDomainName_invalid() {
//        useCase.checkDomainName = { _ in
//            .just(.failure(SimpleErrorMessage(message: "error")))
//        }
//
//        input.onNext(.shopDomainDidChange("foo"))
//
//        state.assertLastValue(State(selectedDomainName: "foo", domainErrorMessage: "error"))
//    }
//
//    func test_inputCity_dismissed() {
//        input.onNext(.cityDidDismissed)
//
//        state.assertLastValue(State(cityError: .dismissed))
//    }
//
//    func test_inputCity_success() {
//        let city = City(id: 1, name: "Hyrule")
//        input.onNext(.cityDidSelected(city))
//
//        state.assertLastValue(State(city: city))
//
//        input.onNext(.cityDidDismissed)
//
//        state.assertLastValue(State(city: city))
//    }
//
//    func test_inputDistrict_success() {
//        let city = City(id: 2, name: "Tokyo")
//        let district = District(id: 1, name: "Shibuya")
//
//        input.onNext(.cityDidSelected(city))
//        state.assertLastValue(State(city: city))
//
//        input.onNext(.districtDidTapped)
//
//        showDistrictSelection.assertDidEmitValues(count: 1)
//
//        input.onNext(.districtDidSelected(district))
//
//        state.assertLastValue(State(city: city, district: district))
//    }
//
//    func test_inputDistrict_noCitySelected() {
//        input.onNext(.districtDidTapped)
//
//        state.assertLastValue(State(districtError: .noCitySelected))
//    }
//
//    func test_inputDistrict_dismissed() {
//        let city = City(id: 2, name: "Tokyo")
//
//        input.onNext(.cityDidSelected(city))
//        state.assertLastValue(State(city: city))
//
//        input.onNext(.districtDidTapped)
//
//        showDistrictSelection.assertDidEmitValues(count: 1)
//
//        input.onNext(.districtDidDismissed)
//
//        state.assertLastValue(State(city: city, districtError: .dismissed))
//    }
//
//    func test_allFieldsValid_willSubmitToServer() {
//        let city = City(id: 2, name: "Tokyo")
//        let district = District(id: 1, name: "Shibuya")
//
//        useCase.checkShopName = { _ in
//            .just(ValidateShopNameResponse(suggestedDomain: "foo-domain", shopNameErrorMessage: nil))
//        }
//
//
//        useCase.submit = { _ in
//            .just(.success(()))
//        }
//
//        input.onNext(.shopNameDidChange("foo-shop"))
//        state.assertLastValue(State(shopName: "foo-shop", selectedDomainName: "foo-domain"))
//
//        input.onNext(.cityDidSelected(city))
//        state.assertLastValue(State(shopName: "foo-shop", selectedDomainName: "foo-domain", city: city))
//
//        input.onNext(.districtDidTapped)
//
//        input.onNext(.districtDidSelected(district))
//        state.assertLastValue(State(shopName: "foo-shop", selectedDomainName: "foo-domain", city: city, district: district))
//
//        input.onNext(.submitButtonDidTap)
//
//        submissionResult.assertDidEmitValues(count: 1)
//    }
}

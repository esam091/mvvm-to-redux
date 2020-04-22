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

struct Step<Value, Action> {
    let kind: Kind
    let action: Action?
    let update: (inout Value) -> Void
    let file: StaticString
    let line: UInt
    
    enum Kind {
        case send
        case receive
    }
    
    init(_ kind: Kind, action: Action?, file: StaticString = #file, line: UInt = #line, update: @escaping (inout Value) -> Void = { _ in }) {
        self.kind = kind
        self.update = update
        self.file = file
        self.line = line
        self.action = action
    }
}

func assertSteps<Value: Equatable, Action: Equatable, Environment>(
    initialValue: Value,
    reducer: @escaping (inout Value, Action, Environment) -> [Driver<Action>],
    environment: Environment,
    steps: Step<Value, Action>...,
    file: StaticString = #file,
    line: UInt = #line
) {
    var pendingEffects: [Driver<Action>] = []
    var value = initialValue
    let disposeBag = DisposeBag()
    
    steps.forEach { step in
        var expected = value
        
        switch step.kind {
        case .send:
            if !pendingEffects.isEmpty {
                XCTFail("Unprocessed effect detected before sending another action", file: step.file, line: step.line)
            }
            
            guard let action = step.action else {
                XCTAssertNotNil(step.action, "Actions cannot be nil when sending", file: step.file, line: step.line)
                break
            }
            
            let effects = reducer(&value, action, environment)
            pendingEffects.append(contentsOf: effects)
            
        case .receive:
            if pendingEffects.isEmpty {
                XCTFail("No more effect to process", file: step.file, line: step.line)
                break
            }
            
            let waiter = XCTWaiter()
            let expectation = XCTestExpectation(description: "stream completion")
            
            var receivedAction: Action?
            
            let effect = pendingEffects.removeFirst()
            effect
                .drive(onNext: { action in
                    receivedAction = action
                }, onCompleted: {
                    expectation.fulfill()
                })
                .disposed(by: disposeBag)
            
            waiter.wait(for: [expectation], timeout: 0.01)
            
            
            
            if let action = receivedAction {
                XCTAssertEqual(step.action, action, file: step.file, line: step.line)
                
                let effects = reducer(&value, action, environment)
                pendingEffects.append(contentsOf: effects)
            }
        }
        
        
        step.update(&expected)
        
        XCTAssertEqual(value, expected, file: step.file, line: step.line)
    }
    
    if !pendingEffects.isEmpty {
        XCTFail("There are still \(pendingEffects.count) unprocessed effects", file: file, line: line)
    }
}

class OpenShopTests: XCTestCase {
    
    func test_inputShowName_showDomainSuggestion() {
        var useCase = UseCase.mock
        useCase.checkShopName = { _ in
            Driver.just(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))
        }
        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopNameDidChange("my shop")) {
                $0.shopName = "my shop"
            },
            Step(.receive, action: .didValidateShopName(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))) {
                $0.selectedDomainName = "foo"
            }
        )
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

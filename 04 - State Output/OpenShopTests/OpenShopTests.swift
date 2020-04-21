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

class TestObserver<Element>: ObserverType {
    private var events: [Event<Element>] = []
    
    func on(_ event: Event<Element>) {
        events.append(event)
    }
    
    func assertDidEmitValues(count: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(events.count, count, file: file, line: line)
    }
}

extension TestObserver where Element: Equatable {
    func assertValues(_ values: [Element], file: StaticString = #file, line: UInt = #line) {
        let storedValues = events.filter { $0.element != nil }.map { $0.element! }
        
        XCTAssertEqual(storedValues, values, file: file, line: line)
        
    }
    
    func assertLastValue(_ value: Element, file: StaticString = #file, line: UInt = #line) {
        guard let lastValue = events.filter({ $0.element != nil }).map({ $0.element! }).last else {
            XCTFail("value not found", file: file, line: line)
            return
        }
        
        XCTAssertEqual(lastValue, value, file: file, line: line)
    }
}



class OpenShopTests: XCTestCase {
    var viewModel: ViewModel!
    var useCase: UseCase!
    var input = PublishSubject<OpenShopInput>()
    
    var disposeBag = DisposeBag()
    
    let showDistrictSelection = TestObserver<Void>()
    let submissionResult = TestObserver<Result<Void, SimpleErrorMessage>>()
    let state = TestObserver<State>()
    
    override func tearDown() {
        disposeBag = DisposeBag()
    }
    
    override func setUp() {
        useCase = UseCase.mock
        viewModel = ViewModel(useCase: useCase)
        
        let output = viewModel.transform(input.asDriver(onErrorDriveWith: .empty()))
        
        output.showDistrictSelection.drive(showDistrictSelection).disposed(by: disposeBag)
        output.submissionResult.drive(submissionResult).disposed(by: disposeBag)
        output.state.drive(state).disposed(by: disposeBag   )
    }

    func test_inputShowName_showDomainSuggestion() {
        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))
        }

        input.onNext(.shopNameDidChange("something"))

        state.assertLastValue(State(shopName: "something", selectedDomainName: "foo"))
        

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
//
//        wait(for: [called], timeout: 0.001)
//
//        shopNameError.assertValues([nil, "error message"])
//        domainName.assertValues(["bar"])
//    }
//
//    func test_inputDomainName_valid() {
//        useCase.checkDomainName = { _ in
//            .just(.success(()))
//        }
//
//        input.onNext(.shopDomainDidChange("foo"))
//
//        domainNameError.assertValues([nil, nil])
//    }
//
//    func test_inputDomainName_invalid() {
//        useCase.checkDomainName = { _ in
//            .just(.failure(SimpleErrorMessage(message: "error")))
//        }
//
//        input.onNext(.shopDomainDidChange("foo"))
//
//        domainNameError.assertValues([nil, "error"])
//    }
//
//    func test_inputCity_dismissed() {
//        input.onNext(.cityDidDismissed)
//
//        citySelectionError.assertValues([.dismissed])
//    }
//
//    func test_inputCity_success() {
//        let city = City(id: 1, name: "Hyrule")
//        input.onNext(.cityDidSelected(city))
//
//        selectedCity.assertValues([city])
//
//            input.onNext(.cityDidDismissed)
//
//        selectedCity.assertValues([city])
//    }
//
//    func test_inputDistrict_success() {
//        let city = City(id: 2, name: "Tokyo")
//        let district = District(id: 1, name: "Shibuya")
//
//        input.onNext(.cityDidSelected(city))
//
//        input.onNext(.districtDidTapped)
//
//        showDistrictSelection.assertDidEmitValues(count: 1)
//
//        input.onNext(.districtDidSelected(district))
//
//        selectedDistrict.assertValues([district])
//    }
//
//    func test_inputDistrict_noCitySelected() {
//        input.onNext(.districtDidTapped)
//
//        districtSelectionError.assertValues([.noCitySelected])
//    }
//
//    func test_inputDistrict_dismissed() {
//        let city = City(id: 2, name: "Tokyo")
//
//        input.onNext(.cityDidSelected(city))
//
//        input.onNext(.districtDidTapped)
//
//        showDistrictSelection.assertDidEmitValues(count: 1)
//
//        input.onNext(.districtDidDismissed)
//
//        districtSelectionError.assertValues([nil, .dismissed])
//    }
    
    func test_allFieldsValid_willSubmitToServer() {
        let city = City(id: 2, name: "Tokyo")
        let district = District(id: 1, name: "Shibuya")
        
        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo-domain", shopNameErrorMessage: nil))
        }
        

        useCase.submit = { _ in
            .just(.success(()))
        }
        input.onNext(.shopNameDidChange("foo-shop"))
        
        input.onNext(.cityDidSelected(city))
        
        input.onNext(.districtDidTapped)
        
        input.onNext(.districtDidSelected(district))
        
        input.onNext(.submitButtonDidTap)
        
        submissionResult.assertDidEmitValues(count: 1)
    }
}

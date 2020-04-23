//
//  Utils.swift
//  OpenShopRedux
//
//  Created by Samuel Edwin on 08/01/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import UIKit

extension Reactive where Base == UITextField {
    var textChanged: Observable<String> {
        return  base.rx.controlEvent(.editingChanged).map { self.base.text! }
    }
    
    
}

struct SimpleErrorMessage: Error, Equatable {
    let message: String
    
    init(message: String) {
        self.message = message
    }
}

protocol ResultType {
    associatedtype Success
    associatedtype Failure: Error
}

extension Result: ResultType {}


extension SharedSequence where Element: ResultType {
    var success: SharedSequence<SharingStrategy, Element.Success> {
        return self.flatMap {
            let result = $0 as! Result<Element.Success, Element.Failure>
            
            switch result {
            case let .success(success): return .just(success)
            case .failure: return .empty()
            }
        }
    }
    
    var failure: SharedSequence<SharingStrategy, Element.Failure> {
        return self.flatMap {
            let result = $0 as! Result<Element.Success, Element.Failure>
            
            switch result {
            case .success: return .empty()
            case let .failure(failure): return .just(failure)
            }
        }
    }
}


class UseCase {
    var checkShopName: (String) -> Driver<ValidateShopNameResponse>
    var checkDomainName: (String) -> Driver<Result<(), SimpleErrorMessage>>
    var submit: (Form) -> Driver<Result<Unit, SimpleErrorMessage>>
    
    init(
        checkShopName: @escaping (String) -> Driver<ValidateShopNameResponse>,
        checkDomainName: @escaping (String) -> Driver<Result<(), SimpleErrorMessage>>,
        submit: @escaping (Form) -> Driver<Result<Unit, SimpleErrorMessage>>
    ) {
        self.checkShopName = checkShopName
        self.checkDomainName = checkDomainName
        self.submit = submit
    }
}

extension UseCase {
    static var mock: UseCase {
        UseCase(checkShopName: { _ in .empty() },
                checkDomainName: { _ in .empty() },
                submit: { _ in .empty() })
    }
    
    
}

enum CitySelectionError: Error {
    case dismissed
}

enum DistrictSelectionError: Error {
    case dismissed
    case noCitySelected
}


struct ValidateShopNameResponse: Equatable {
    let suggestedDomain: String
    let shopNameErrorMessage: String?
}

struct City: Equatable {
    let id: Int
    let name: String
}

struct District: Equatable {
    let id: Int
    let name: String
}

struct Form {
    let domainName: String
    let shopName: String
    let cityID: Int
    let districtID: Int
}

//
//  PublishedPipeline.swift
//  Clip
//
//  Created by Riley Testut on 12/4/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Combine

@available(iOS 13.0, *)
@propertyWrapper
class PublishedPipeline<Value, Pipeline: Publisher> {
    @Published
    var wrappedValue: Value

    var projectedValue: AnyPublisher<Pipeline.Output, Pipeline.Failure> {
        return self.pipeline(self.$wrappedValue.eraseToAnyPublisher()).eraseToAnyPublisher()
    }

    private let pipeline: (AnyPublisher<Value, Never>) -> Pipeline

    init(wrappedValue: Value, _ pipeline: @escaping (AnyPublisher<Value, Never>) -> Pipeline) {
        self.wrappedValue = wrappedValue
        self.pipeline = pipeline
    }
}

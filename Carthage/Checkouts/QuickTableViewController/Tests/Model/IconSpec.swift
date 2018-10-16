//
//  IconSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 17/01/2016.
//  Copyright © 2016 bcylin.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Nimble
import Quick
@testable import QuickTableViewController

internal final class IconSpec: QuickSpec {

  override func spec() {

    describe("initialization") {
      let image = UIImage()

      context("image") {
        let icon = Icon.image(image)
        it("should initialize with the image") {
          expect(icon.image) == image
          expect(icon.highlightedImage).to(beNil())
        }
      }

      context("image name") {
        let icon = Icon.named("name")
        it("should initialize with the image name") {
          expect(icon.image).to(beNil())
          expect(icon.highlightedImage).to(beNil())
        }
      }
    }

    describe("equatable") {
      let image = UIImage()
      let a = Icon.image(image)

      context("identical images") {
        let b = Icon.image(image)
        it("should be equal") {
          expect(a) == b
        }
      }

      context("different images") {
        let c = Icon.image(UIImage())
        it("should not be equal") {
          expect(a) != c
        }
      }

      context("different highlighted images") {
        let d = Icon.images(normal: image, highlighted: UIImage())
        let e = Icon.images(normal: image, highlighted: UIImage())
        it("should not be equal") {
          expect(d) != e
        }
      }

      let f = Icon.named("Same")

      context("different image specification") {
        it("should not be queal") {
          expect(a) != f
        }
      }

      context("identical image names") {
        let g = Icon.named("Same")
        it("should be eqaul") {
          expect(f) == g
        }
      }

      context("different image names") {
        let h = Icon.named("Different")
        it("should not be equal") {
          expect(f) != h
        }
      }
    }
  }

}

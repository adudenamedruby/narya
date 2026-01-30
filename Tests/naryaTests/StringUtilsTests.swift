// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("StringUtils Tests", .serialized)
struct StringUtilsTests {
    // MARK: - camelToSnakeCase Tests

    @Test("camelToSnakeCase converts simple camelCase")
    func camelToSnakeCaseSimple() {
        #expect(StringUtils.camelToSnakeCase("testButtress") == "test_buttress")
        #expect(StringUtils.camelToSnakeCase("helloWorld") == "hello_world")
    }

    @Test("camelToSnakeCase handles single word")
    func camelToSnakeCaseSingleWord() {
        #expect(StringUtils.camelToSnakeCase("test") == "test")
        #expect(StringUtils.camelToSnakeCase("hello") == "hello")
    }

    @Test("camelToSnakeCase handles empty string")
    func camelToSnakeCaseEmpty() {
        #expect(StringUtils.camelToSnakeCase("").isEmpty)
    }

    @Test("camelToSnakeCase handles single character")
    func camelToSnakeCaseSingleChar() {
        #expect(StringUtils.camelToSnakeCase("a") == "a")
        #expect(StringUtils.camelToSnakeCase("A") == "a")
    }

    @Test("camelToSnakeCase handles multiple uppercase letters")
    func camelToSnakeCaseMultipleUppercase() {
        #expect(StringUtils.camelToSnakeCase("myURLParser") == "my_u_r_l_parser")
        #expect(StringUtils.camelToSnakeCase("parseHTTPResponse") == "parse_h_t_t_p_response")
    }

    @Test("camelToSnakeCase handles leading uppercase")
    func camelToSnakeCaseLeadingUppercase() {
        #expect(StringUtils.camelToSnakeCase("TestCase") == "test_case")
        #expect(StringUtils.camelToSnakeCase("HelloWorld") == "hello_world")
    }

    @Test("camelToSnakeCase handles strings with numbers")
    func camelToSnakeCaseWithNumbers() {
        #expect(StringUtils.camelToSnakeCase("test123Case") == "test123_case")
        #expect(StringUtils.camelToSnakeCase("iPhone16Pro") == "i_phone16_pro")
    }

    // MARK: - camelToKebabCase Tests

    @Test("camelToKebabCase converts simple camelCase")
    func camelToKebabCaseSimple() {
        #expect(StringUtils.camelToKebabCase("testButtress") == "test-buttress")
        #expect(StringUtils.camelToKebabCase("helloWorld") == "hello-world")
    }

    @Test("camelToKebabCase handles single word")
    func camelToKebabCaseSingleWord() {
        #expect(StringUtils.camelToKebabCase("test") == "test")
        #expect(StringUtils.camelToKebabCase("hello") == "hello")
    }

    @Test("camelToKebabCase handles empty string")
    func camelToKebabCaseEmpty() {
        #expect(StringUtils.camelToKebabCase("").isEmpty)
    }

    @Test("camelToKebabCase handles single character")
    func camelToKebabCaseSingleChar() {
        #expect(StringUtils.camelToKebabCase("a") == "a")
        #expect(StringUtils.camelToKebabCase("A") == "a")
    }

    @Test("camelToKebabCase handles multiple uppercase letters")
    func camelToKebabCaseMultipleUppercase() {
        #expect(StringUtils.camelToKebabCase("myURLParser") == "my-u-r-l-parser")
        #expect(StringUtils.camelToKebabCase("parseHTTPResponse") == "parse-h-t-t-p-response")
    }

    @Test("camelToKebabCase handles leading uppercase")
    func camelToKebabCaseLeadingUppercase() {
        #expect(StringUtils.camelToKebabCase("TestCase") == "test-case")
        #expect(StringUtils.camelToKebabCase("HelloWorld") == "hello-world")
    }

    @Test("camelToKebabCase handles strings with numbers")
    func camelToKebabCaseWithNumbers() {
        #expect(StringUtils.camelToKebabCase("test123Case") == "test123-case")
        #expect(StringUtils.camelToKebabCase("iPhone16Pro") == "i-phone16-pro")
    }

    // MARK: - camelToTitleCase Tests

    @Test("camelToTitleCase converts simple camelCase")
    func camelToTitleCaseSimple() {
        #expect(StringUtils.camelToTitleCase("testButtress") == "Test Buttress")
        #expect(StringUtils.camelToTitleCase("helloWorld") == "Hello World")
    }

    @Test("camelToTitleCase handles single word")
    func camelToTitleCaseSingleWord() {
        #expect(StringUtils.camelToTitleCase("test") == "Test")
        #expect(StringUtils.camelToTitleCase("hello") == "Hello")
    }

    @Test("camelToTitleCase handles empty string")
    func camelToTitleCaseEmpty() {
        #expect(StringUtils.camelToTitleCase("").isEmpty)
    }

    @Test("camelToTitleCase handles single character")
    func camelToTitleCaseSingleChar() {
        #expect(StringUtils.camelToTitleCase("a") == "A")
        #expect(StringUtils.camelToTitleCase("A") == "A")
    }

    @Test("camelToTitleCase handles multiple uppercase letters")
    func camelToTitleCaseMultipleUppercase() {
        #expect(StringUtils.camelToTitleCase("myURLParser") == "My U R L Parser")
        #expect(StringUtils.camelToTitleCase("parseHTTPResponse") == "Parse H T T P Response")
    }

    @Test("camelToTitleCase handles leading uppercase")
    func camelToTitleCaseLeadingUppercase() {
        #expect(StringUtils.camelToTitleCase("TestCase") == "Test Case")
        #expect(StringUtils.camelToTitleCase("HelloWorld") == "Hello World")
    }

    @Test("camelToTitleCase handles strings with numbers")
    func camelToTitleCaseWithNumbers() {
        #expect(StringUtils.camelToTitleCase("test123Case") == "Test123 Case")
        #expect(StringUtils.camelToTitleCase("iPhone16Pro") == "I Phone16 Pro")
    }

    // MARK: - capitalizeFirst Tests

    @Test("capitalizeFirst capitalizes first letter")
    func capitalizeFirstSimple() {
        #expect(StringUtils.capitalizeFirst("test") == "Test")
        #expect(StringUtils.capitalizeFirst("hello") == "Hello")
    }

    @Test("capitalizeFirst handles empty string")
    func capitalizeFirstEmpty() {
        #expect(StringUtils.capitalizeFirst("").isEmpty)
    }

    @Test("capitalizeFirst handles single character")
    func capitalizeFirstSingleChar() {
        #expect(StringUtils.capitalizeFirst("a") == "A")
        #expect(StringUtils.capitalizeFirst("A") == "A")
    }

    @Test("capitalizeFirst handles already capitalized")
    func capitalizeFirstAlreadyCapitalized() {
        #expect(StringUtils.capitalizeFirst("Test") == "Test")
        #expect(StringUtils.capitalizeFirst("HELLO") == "HELLO")
    }

    @Test("capitalizeFirst handles strings with numbers")
    func capitalizeFirstWithNumbers() {
        #expect(StringUtils.capitalizeFirst("123test") == "123test")
        #expect(StringUtils.capitalizeFirst("test123") == "Test123")
    }

    @Test("capitalizeFirst preserves rest of string")
    func capitalizeFirstPreservesRest() {
        #expect(StringUtils.capitalizeFirst("tEST") == "TEST")
        #expect(StringUtils.capitalizeFirst("hELLO wORLD") == "HELLO wORLD")
    }
}

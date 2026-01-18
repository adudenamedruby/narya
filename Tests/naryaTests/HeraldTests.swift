// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("Herald Tests", .serialized)
struct HeraldTests {

    // MARK: - Test Helpers
    private let indentChar = "▒"

    /// Captures stdout output from a closure
    private func captureOutput(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        block()

        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - First Line Tests (isNewCommand)

    @Test("First line uses ring prefix")
    func firstLineUsesRingPrefix() {
        let output = captureOutput {
            Herald.declare("Hello", isNewCommand: true)
        }
        #expect(output == "💍 Hello\n")
    }

    @Test("First line with asError uses ring and error prefix")
    func firstLineWithErrorUsesRingAndErrorPrefix() {
        let output = captureOutput {
            Herald.declare("Error occurred", asError: true, isNewCommand: true)
        }
        #expect(output == "💍 💥 Error occurred\n")
    }

    @Test("First line with asConclusion uses ring prefix")
    func firstLineWithConclusionUsesRingPrefix() {
        let output = captureOutput {
            Herald.declare("Done!", isNewCommand: true, asConclusion: true)
        }
        #expect(output == "💍 Done!\n")
    }

    @Test("First line with asError and asConclusion uses ring and error prefix")
    func firstLineWithErrorAndConclusionUsesRingAndErrorPrefix() {
        let output = captureOutput {
            Herald.declare("Failed!", asError: true, isNewCommand: true, asConclusion: true)
        }
        #expect(output == "💍 💥 Failed!\n")
    }

    // MARK: - Subsequent Line Tests

    @Test("Subsequent line uses continuation prefix")
    func subsequentLineUsesContinuationPrefix() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Second")
        }
        #expect(output == "💍 First\n\(indentChar) Second\n")
    }

    @Test("Subsequent line with asError uses continuation and error prefix")
    func subsequentLineWithErrorUsesContinuationAndErrorPrefix() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Error occurred", asError: true)
        }
        #expect(output == "💍 First\n\(indentChar) 💥 Error occurred\n")
    }

    @Test("Subsequent line with asConclusion uses ring prefix")
    func subsequentLineWithConclusionUsesRingPrefix() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Done!", asConclusion: true)
        }
        #expect(output == "💍 First\n💍 Done!\n")
    }

    @Test("Subsequent line with asError and asConclusion uses ring and error prefix")
    func subsequentLineWithErrorAndConclusionUsesRingAndErrorPrefix() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Failed!", asError: true, asConclusion: true)
        }
        #expect(output == "💍 First\n💍 💥 Failed!\n")
    }

    // MARK: - Multi-line Message Tests

    @Test("Multi-line message on first call uses ring then sub-continuation")
    func multiLineMessageFirstCallUsesRingThenSubContinuation() {
        let output = captureOutput {
            Herald.declare("Line one\nLine two\nLine three", isNewCommand: true)
        }
        #expect(output == "💍 Line one\n\(indentChar) \(indentChar) Line two\n\(indentChar) \(indentChar) Line three\n")
    }

    @Test("Multi-line message on subsequent call uses continuation then sub-continuation")
    func multiLineMessageSubsequentCallUsesContinuationThenSubContinuation() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Line one\nLine two")
        }
        #expect(output == "💍 First\n\(indentChar) Line one\n\(indentChar) \(indentChar) Line two\n")
    }

    @Test("Multi-line error message uses error prefix only on first line")
    func multiLineErrorMessageUsesErrorPrefixOnlyOnFirstLine() {
        let output = captureOutput {
            Herald.declare("Error line one\nError line two", asError: true, isNewCommand: true)
        }
        #expect(output == "💍 💥 Error line one\n\(indentChar) \(indentChar) Error line two\n")
    }

    @Test("Multi-line conclusion message uses ring prefix only on first line")
    func multiLineConclusionMessageUsesRingPrefixOnlyOnFirstLine() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Conclusion line one\nConclusion line two", asConclusion: true)
        }
        #expect(output == "💍 First\n💍 Conclusion line one\n\(indentChar) \(indentChar) Conclusion line two\n")
    }

    // MARK: - isNewCommand Tests

    @Test("isNewCommand restores first line behavior")
    func isNewCommandRestoresFirstLineBehavior() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Second")
            Herald.declare("After new command", isNewCommand: true)
        }
        #expect(output == "💍 First\n\(indentChar) Second\n💍 After new command\n")
    }

    @Test("Multiple isNewCommand calls work correctly")
    func multipleIsNewCommandCallsWorkCorrectly() {
        let output = captureOutput {
            Herald.declare("A", isNewCommand: true)
            Herald.declare("B", isNewCommand: true)
            Herald.declare("C", isNewCommand: true)
        }
        #expect(output == "💍 A\n💍 B\n💍 C\n")
    }

    // MARK: - State Behavior Tests

    @Test("After conclusion, subsequent calls use normal continuation")
    func afterConclusionSubsequentCallsUseNormalContinuation() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Conclusion", asConclusion: true)
            Herald.declare("After conclusion")
        }
        #expect(output == "💍 First\n💍 Conclusion\n\(indentChar) After conclusion\n")
    }

    @Test("asError does not affect state")
    func asErrorDoesNotAffectState() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Error", asError: true)
            Herald.declare("After error")
        }
        #expect(output == "💍 First\n\(indentChar) 💥 Error\n\(indentChar) After error\n")
    }

    @Test("After multi-line message, subsequent calls use normal continuation")
    func afterMultiLineMessageSubsequentCallsUseNormalContinuation() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Multi\nLine")
            Herald.declare("After multi-line")
        }
        #expect(output == "💍 First\n\(indentChar) Multi\n\(indentChar) \(indentChar) Line\n\(indentChar) After multi-line\n")
    }

    @Test("After multi-line message, asError works normally")
    func afterMultiLineMessageAsErrorWorksNormally() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Multi\nLine")
            Herald.declare("Error after multi-line", asError: true)
        }
        #expect(output == "💍 First\n\(indentChar) Multi\n\(indentChar) \(indentChar) Line\n\(indentChar) 💥 Error after multi-line\n")
    }

    @Test("After multi-line message, conclusion works normally")
    func afterMultiLineMessageConclusionWorksNormally() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Multi\nLine")
            Herald.declare("Conclusion", asConclusion: true)
        }
        #expect(output == "💍 First\n\(indentChar) Multi\n\(indentChar) \(indentChar) Line\n💍 Conclusion\n")
    }

    @Test("After conclusion, asConclusion and asError are ignored")
    func afterConclusionFlagsAreIgnored() {
        let output = captureOutput {
            Herald.declare("First", isNewCommand: true)
            Herald.declare("Conclusion 1", asConclusion: true)
            Herald.declare("Conclusion 2", asError: true, asConclusion: true)
        }
        #expect(output == "💍 First\n💍 Conclusion 1\n\(indentChar) Conclusion 2\n")
    }

    // MARK: - Edge Cases

    @Test("Empty message still outputs prefix")
    func emptyMessageStillOutputsPrefix() {
        let output = captureOutput {
            Herald.declare("", isNewCommand: true)
        }
        #expect(output == "💍 \n")
    }

    @Test("Message with only newlines")
    func messageWithOnlyNewlines() {
        let output = captureOutput {
            Herald.declare("\n\n", isNewCommand: true)
        }
        // Three empty lines: first gets 💍, subsequent get ▒ ▒
        #expect(output == "💍 \n\(indentChar) \(indentChar) \n\(indentChar) \(indentChar) \n")
    }

    @Test("Long sequence of calls")
    func longSequenceOfCalls() {
        let output = captureOutput {
            Herald.declare("1", isNewCommand: true)
            Herald.declare("2")
            Herald.declare("3")
            Herald.declare("4")
            Herald.declare("5")
        }
        #expect(output == "💍 1\n\(indentChar) 2\n\(indentChar) 3\n\(indentChar) 4\n\(indentChar) 5\n")
    }

    @Test("Mixed normal and conclusion calls")
    func mixedNormalAndConclusionCalls() {
        let output = captureOutput {
            Herald.declare("Starting...", isNewCommand: true)
            Herald.declare("Processing...")
            Herald.declare("Done!", asConclusion: true)
        }
        #expect(output == "💍 Starting...\n\(indentChar) Processing...\n💍 Done!\n")
    }

    @Test("Interleaved errors and normal messages")
    func interleavedErrorsAndNormalMessages() {
        let output = captureOutput {
            Herald.declare("Step 1", isNewCommand: true)
            Herald.declare("Warning!", asError: true)
            Herald.declare("Step 2")
            Herald.declare("Error!", asError: true)
            Herald.declare("Completed with errors", asError: true, asConclusion: true)
        }
        #expect(output == "💍 Step 1\n\(indentChar) 💥 Warning!\n\(indentChar) Step 2\n\(indentChar) 💥 Error!\n💍 💥 Completed with errors\n")
    }

    @Test("Source of truth expected output")
    func sourceOfTruthExpectedOutput() {
        let output = captureOutput {
            Herald.declare("Step 1", isNewCommand: true)
            Herald.declare("Step 2")
            Herald.declare("Warning!", asError: true)
            Herald.declare("Step 3")
            Herald.declare("Error!\nError Step 2", asError: true)
            Herald.declare("Yet another error!", asError: true)
            Herald.declare("Step 4")
            Herald.declare("Step 5\nStep 6\nStep 7")
            Herald.declare("Step 8")
            Herald.declare("Completed with errors", asError: true, asConclusion: true)
            Herald.declare("Completed with errors step 2", asError: true, asConclusion: true)
        }
        #expect(output == "💍 Step 1\n\(indentChar) Step 2\n\(indentChar) 💥 Warning!\n\(indentChar) Step 3\n\(indentChar) 💥 Error!\n\(indentChar) \(indentChar) Error Step 2\n\(indentChar) 💥 Yet another error!\n\(indentChar) Step 4\n\(indentChar) Step 5\n\(indentChar) \(indentChar) Step 6\n\(indentChar) \(indentChar) Step 7\n\(indentChar) Step 8\n💍 💥 Completed with errors\n\(indentChar) Completed with errors step 2\n")
    }
}

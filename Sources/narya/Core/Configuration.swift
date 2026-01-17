// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum Configuration {
    static let name = "narya"
    static let version = "20260116.5"
    static let shortDescription = "A helper CLI for the firefox-ios repository"
    static let longDescription = """
        On the Origins of Narya

        In the days of the making of the Rings, when the skill of the Elven-smiths
        was yet unmarred, three Rings of Power were wrought, untainted by the shadow
        of Sauron: a ring of air, a ring of water, and a ring of red fire, whose name
        was Narya. Narya was not forged for dominion, nor to bend wills of others,
        but for the kindling of hearts long pressed by weariness and fear, a font
        of guidance and endurance in the shadow of the long dark.

        Long did Narya remain with Círdan the Shipwright, who kept watch upon the
        Havens while the years of the world flowed by. Yet when Mithrandir came out
        of the West, cloaked in grey and seeming frail, Círdan perceived in him
        a spirit of steadfast fire, and to him he gave the Ring, knowing that such
        a gift was better borne by one who did not seek to master.

        Thus it came to pass that wherever Gandalf went, hope arose again, though
        few understood the source of that renewal. In dark councils and upon bitter
        roads, among the small and the great alike, he labored to awaken courage
        where it had grown cold, and to withstand despair, which is the shadow
        of the Enemy’s triumph.

        And when at last the One was unmade and the power of the Three was spent,
        Narya’s fire was not quenched in ruin, but passed from the circles of the
        world, having fulfilled its purpose. For its flame was ever meant to warm,
        not to consume, and to endure only while hope was needed in Middle-earth.
        """
    static let markerFileName = ".narya.yaml"

    static var aboutText: String {
        """
        \(name) v\(version)

        `narya` provides a single entry point for the running of common tasks,
        automations, and workflows used in the development of mozilla-mobile/firefox-ios.

        forged by @adudenamedruby

        \(longDescription)
        """
    }
}

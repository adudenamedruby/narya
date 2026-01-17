I want to update what the nimbus subcommand does. It will in essence, do the same thing as it is currently doing, but in a slightly more complete way.

Please first read the README.md file in this repo to understand the project well.
Please also read the Nimbus command file, to get an understanding of how it currently works. The nimbus folder locations are not changing, so do not change those.

A brief note on my how I'd like to the feature names to be standardized:

- throughout the documentation, we should refer to them, when passed as an option as <featureName>
- feature names passed by the user should be camelCased but should not contain the suffix `Feature` at the end; it it is present, remove it
- the current actions of adding the `Feature` suffix to the yaml files is correct; the suffix should not be present in the Swift files
- I will be using <featureName> as a placeholder for the actual feature name, so, if a feature is called testButress, then `.<featureName>` in this document is a shorthand for `.testButress`

I'd like the nimbus command to have the following options subcommands:

refresh (changed from --refresh)
I would like this to operate the same as it does today, where it ensures that the nimbus feature files in the respective folder are properly listed in the parent file.

add <featureName> (changed from --add)
I would like this to add a feature in the nimbus-features folder, and still add that file to the nimbus.fml.yaml file, as it currently does. I would like to build upon this command though, to have it do several more things. I'd like it to also:

1. Make some changes in the NimbusFlaggableFeature.swift file:

- add a case to the NimbusFeatureFlagID enum in the NimbusFlaggableFeature.swift file with the feature name, and make sure that these are alphabetized.
- add a --debug flag to this which will add the feature name in the `var debugKey: String?` case. By default, it doesn't get added to the debugKey
- add a --user-toggleable flag which will add it to the appropriate section to NimbusFlaggableFeature's featureKey var with a `fatalError("Please implement a key for this feature")` for the case. If this flag is not passed, by default, the feature name should be added to default case.

2. Make some changes in the NimbusFeatureFlagLayer.swift file:

- first, it needs to add a case in the `checkNimbusConfigFor` function. The standard format for this will be:

```swift
        case .<featureName>:
            return check<featureName>Feature(from: nimbus)

```

- it will then add a function near the end of the file, but still inside the NimbusFeatureFlagLayer class, with the following format:

```swift
    private func check<featureName>Feature(from nimbus: FxNimbus) -> Bool {
        return nimbus.features.<featureName>.value().enabled
    }
```

3. if the --debug flag was passed, we should also make changes to the FeatureFlagsDebugViewController.swift. in the `generateFeatureFlagToggleSettings` function, we should add the following

```swift
            FeatureFlagsBoolSetting(
                with: .<featureName>,
                titleText: format(string: "<featureName>"),
                statusText: format(string: "Toggle <featureName>")
            ) { [weak self] _ in
                self?.reloadView()
            },

```

This should be added to that section in an alphabetized manner. It is alphabetized by the <featureName>

the add subcommand should also have

remove <featureName>
This should do the reverse of add <feature> name. However, before it removes anything, it should perform checks that it _can_ remove those things. If anything doesn't match the pattern exactly, this should fail without doing anything. This subcommand should not accept any flags. By default, it should check if it needs to remove things from all the places they would have been added.

In the firefox-ios repo, the files mentioned are located with the following paths:
`~/Developer/firefox-ios/firefox-ios/Client/FeatureFlags/NimbusFlaggableFeature.swift`
`~/Developer/firefox-ios/firefox-ios/Client/Frontend/Settings/Main/Debug/FeatureFlags/FeatureFlagsDebugViewController.swift`
`~/Developer/firefox-ios/firefox-ios/Client/Nimbus/NimbusFeatureFlagLayer.swift`

Please think harder about how you would go about doing this, and present a plan before implementing anything. Ask any clarification questions required. Please raise any concerns, and how we might address them.

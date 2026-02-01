import ArgumentParser

struct OpenCodeBar: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "opencodebar",
        abstract: "AI provider usage monitor",
        version: "1.0.0",
        subcommands: [
            Status.self,
            List.self,
            Provider.self,
        ]
    )

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display current usage status for all providers"
        )

        func run() throws {
            print("Status: Fetching provider usage...")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all configured AI providers"
        )

        func run() throws {
            print("Providers: Listing configured providers...")
        }
    }

    struct Provider: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get details for a specific provider"
        )

        @Argument(help: "Provider name (e.g., claude, openrouter, copilot)")
        var name: String

        func run() throws {
            print("Provider: Fetching details for '\(name)'...")
        }
    }

    func run() throws {
        print("OpenCodeBar CLI v1.0.0 - Use --help for usage")
    }
}

OpenCodeBar.main()

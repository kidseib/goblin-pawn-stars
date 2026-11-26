# AI Disclosure

Goblin Pawn Stars is a **human-directed, AI-assisted** project. This page explains
how AI was used, what it was not used for, and how the output is checked.

## Roles

- **ErrorSeib** — maintainer and product owner. Sets requirements, reviews changes,
  and approves what is published.
- **Buffy (Codebuff)** — an AI coding agent used during development for
  implementation, tests, documentation, release tooling, and the README banner
  artwork.

## What AI assisted with

- Lua addon code, UI, data tables, and diagnostics.
- The headless test harness, WoW API mock, and test cases.
- Documentation: README, changelog, testing checklist, release notes, and this
  disclosure.
- Repository tooling: syntax checks, packaging, and the GitHub Actions workflow.
- The README banner SVG.
- The README UI render gallery: HTML/CSS mockups of the intended screens, clearly
  labeled as renders rather than live-client captures.

## What AI is not used for

- **No runtime AI.** The addon does not call an AI model, an external API, or a
  network service.
- **No telemetry.** It does not collect, transmit, or sell player data; there are no
  analytics, ads, or accounts.
- **No generated in-game art or voice.** The UI uses Blizzard textures, icons, and
  fonts; the README banner is the only AI-assisted artwork.
- **No automation of gameplay.** The addon reads bags and simulates a shop; it never
  performs game actions on the player's behalf.

## Human review and testing

AI output is treated as draft work. ErrorSeib reviews changes and approves releases.
The project runs:

- A Lua 5.1 syntax check over every addon file.
- A headless simulation suite and UI smoke pass under fengari with mocked WoW APIs.
- A live-client checklist on the Forever client for release candidates.

Passing automated checks does not prove live-client behavior. See
[TESTING.md](TESTING.md) for what is and is not verified.

## Limitations

AI can make mistakes, including plausible-looking code that is wrong. The tests and
live checks are the source of truth, not the AI's confidence. AI-assisted output may
also raise copyright questions that vary by jurisdiction; the project is released
under the [MIT License](LICENSE), and the maintainer is responsible for the repository
as published.

## Contact

Open a GitHub issue for bugs or questions. Do not include personal information,
account names, or private server details in a public report.

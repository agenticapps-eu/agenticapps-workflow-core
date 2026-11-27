## ADDED Requirements

### Requirement: The initializer updates a section that starts the file

When the begin marker is the first line of an instruction file, the initializer
SHALL update the section as it does anywhere else in the file, and SHALL write no
diagnostic from the tools it uses to do it. The bytes after the end marker SHALL
be unchanged.

#### Scenario: The instruction file is the managed section and nothing else

- **WHEN** the initializer runs where both instruction files hold an outdated section and nothing else, with the begin marker on line 1
- **THEN** it exits zero, replaces the section with the current one, prints no `head:` or other tool error, and the two files are byte-identical to each other
- **AND** a second run prints no tool error and leaves both files unchanged

#### Scenario: Content follows a section that starts the file

- **WHEN** the begin marker is line 1 and operator content follows the end marker
- **THEN** that content is unchanged after the run

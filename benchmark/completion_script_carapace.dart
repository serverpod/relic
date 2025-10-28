/// This file is auto-generated.
library;

import 'package:cli_tools/better_command_runner.dart' show CompletionTool;

const String _completionScript = r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: benchmark
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.

commands:
  - name: completion

    commands:
      - name: generate
        flags:
          -t, --target=!: The target tool format
          -e, --exec-name=: Override the name of the executable
          -f, --file=: Write the specification to a file instead of stdout
        completion:
          flag:
            target: ["completely", "carapace"]
            file: ["$files"]

  - name: run
    flags:
      -o, --output=: The file to write benchmark results to
      -i, --iterations=: Something to do with scale
      -s, --store-in-git-notes: Store benchmark result with git notes
      --no-store-in-git-notes: Store benchmark result with git notes
      -p, --pause-on-startup: Pause on startup to allow devtools to attach
    exclusiveFlags:
      - [store-in-git-notes, no-store-in-git-notes]
    completion:
      flag:
        output: ["$files"]

  - name: extract
    flags:
      -f, --from=: 
      -t, --to=: 


''';

/// Embedded script for command line completion for `carapace`.
const completionScriptCarapace = (
  tool: CompletionTool.carapace,
  script: _completionScript,
);

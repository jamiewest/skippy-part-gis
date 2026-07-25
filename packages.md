# Dart Package Usage Guide for AI Coding Agents

This file tells an AI coding agent which Dart packages are already approved for use and when to prefer them over writing custom code.

Use these packages aggressively when they fit. Before implementing custom parsing, stream control, file abstraction, platform detection, retries, identifiers, caching, command-line parsing, or test helpers, check this guide first.

## General decision rules

1. Prefer small, focused packages from the Dart team or widely used ecosystem packages before writing utility code.
2. Do not reimplement common helpers such as path manipulation, glob matching, YAML parsing, Markdown parsing, UTF-8/JSON conversion, typed byte buffers, command-line argument parsing, stream transformation, or asynchronous coordination.
3. Keep dependencies scoped correctly:
   - `dependencies` for runtime code.
   - `dev_dependencies` for test-only or build-only helpers such as `matcher`, `fake_async`, and sometimes `code_builder`.
4. Prefer package APIs over direct `dart:io` calls when testability or cross-platform abstractions matter.
5. Prefer `package:path` for file paths. Do not concatenate paths with `/` or `\`.
6. Prefer `package:clock` over `DateTime.now()` when code needs deterministic tests.
7. Prefer `package:file` for file system abstraction when code should be testable with an in-memory file system.
8. Prefer `package:async`, `package:stream_transform`, `package:stream_channel`, and `package:pool` for asynchronous coordination instead of hand-rolled stream controllers, queues, semaphores, or cancellation patterns.
9. Prefer `package:collection`, `package:characters`, `package:convert`, and `package:typed_data` for low-level correctness instead of fragile custom helpers.
10. If a package is marked experimental or niche, use it only when the project clearly needs that capability.

## Web servers, HTTP, MIME, and URI handling

### `shelf`

Use for composable Dart HTTP servers, local development servers, API endpoints, middleware pipelines, test servers, and tool servers.

Prefer it when:
- Building a small HTTP API in Dart.
- Creating middleware-like request processing.
- Serving generated files, diagnostics, local tooling endpoints, or agent endpoints.
- Writing handlers that should be easy to test.

Avoid custom code for:
- Routing request objects through middleware.
- Hand-building server abstractions around `HttpServer` unless low-level socket control is required.

Typical concepts:
- `Request`
- `Response`
- `Handler`
- `Middleware`
- `Pipeline`

Common pairings:
- `shelf` + `mime` for content type detection.
- `shelf` + `path` for safe static-file paths.
- `shelf` + `stream_channel` for bidirectional communication patterns.
- `shelf` + `dart_mcp` when exposing model-context tooling over HTTP-style transports.

### `http`

Use for client-side HTTP calls from Dart command-line tools, servers, or Flutter-compatible shared packages.

Prefer it when:
- Calling REST APIs.
- Downloading files.
- Sending JSON payloads.
- Creating testable API clients by injecting a `Client`.

Avoid custom code for:
- Raw `HttpClient` usage unless advanced transport control is needed.
- Manually composing multipart requests if `http` already supports the request shape.

Typical concepts:
- `Client`
- `Request`
- `Response`
- `MultipartRequest`

Common pairings:
- `http` + `retry` for transient network failures.
- `http` + `convert` for JSON and UTF-8.
- `http` + `mime` for upload/download content types.
- `http` + `http_methods` for method constants.

### `mime`

Use for MIME type lookup and content type detection.

Prefer it when:
- Serving files over HTTP.
- Uploading files.
- Inferring content types from file extensions or magic bytes.
- Avoiding hard-coded content type maps.

Common pairings:
- `mime` + `shelf` for static responses.
- `mime` + `http` for uploads.
- `mime` + `path` for extension-based lookup.

### `uri`

Use when the project needs URI utilities beyond `dart:core`'s `Uri` class.

Prefer it when:
- A package provides helpers for URI templates, manipulation, encoding, or normalization that are clearer than custom string logic.
- Handling complex URL or URI transformations.

Avoid:
- String concatenation for URLs.
- Manual query string encoding.

Always check whether `dart:core Uri` is enough before adding this dependency.

### `http_methods`

Use for HTTP method constants and method-related helpers.

Prefer it when:
- Avoiding typo-prone string literals like `'GET'`, `'POST'`, `'PATCH'` across code.
- Implementing HTTP routers, middleware, or clients.

Common pairings:
- `http_methods` + `shelf`.
- `http_methods` + `http`.

## Files, paths, processes, globbing, and watching

### `path`

Use for all path manipulation.

Prefer it when:
- Joining paths.
- Getting extensions, basenames, directories, relative paths, canonical paths.
- Working across Windows, macOS, Linux, and web-like path styles.

Avoid custom code for:
- `'$directory/$fileName'` path building.
- Splitting paths manually.
- Assuming `/` separators.

Typical concepts:
- `p.join(...)`
- `p.basename(...)`
- `p.dirname(...)`
- `p.extension(...)`
- `p.relative(...)`
- `Context`

### `file`

Use for file system abstraction and testability.

Prefer it when:
- Code reads/writes files but should be unit-testable without touching the real disk.
- Building tools that operate on project files.
- Creating services where file system access should be injected.

Avoid custom code for:
- Wrapping every `dart:io File`, `Directory`, and `Link` manually.

Typical concepts:
- `FileSystem`
- `LocalFileSystem`
- Memory file system support through companion packages where applicable.

Common pairings:
- `file` + `path`.
- `file` + `glob`.
- `file` + `watcher`.

### `io`

Use for cross-platform input/output helpers and process-related utilities from the Dart tools ecosystem.

Prefer it when:
- Building command-line tools.
- Needing safer or more portable terminal/process/file utilities.
- Avoiding repeated boilerplate around standard input/output or process exits.

Check package APIs before writing low-level `dart:io` helper wrappers.

### `process`

Use for process management abstraction, especially testable process execution.

Prefer it when:
- Running external commands.
- Testing code that invokes command-line tools.
- Abstracting process execution behind injectable managers.

Avoid custom code for:
- Direct scattered `Process.run` calls that are hard to test.
- Manual wrappers around process results.

Common pairings:
- `process` + `platform` for environment-aware command execution.
- `process` + `args` for command-line tools.
- `process` + `retry` for flaky external commands.

### `glob`

Use for matching file paths with glob patterns.

Prefer it when:
- Expanding `**/*.dart`, `lib/**`, `test/**/*_test.dart`, etc.
- Implementing include/exclude rules.
- Matching project files in tooling.

Avoid custom code for:
- Recursive directory matching with hand-written wildcard parsing.

Common pairings:
- `glob` + `path`.
- `glob` + `file`.
- `glob` + `watcher`.

### `watcher`

Use for file system change notifications.

Prefer it when:
- Rebuilding generated code when files change.
- Watching source folders in developer tools.
- Triggering reloads or incremental scans.

Avoid custom code for:
- Polling directories manually.
- Platform-specific file watching logic.

Common pairings:
- `watcher` + `glob` for filtering watched paths.
- `watcher` + `stream_transform` for debouncing file events.
- `watcher` + `pool` for limiting rebuild concurrency.

### `platform`

Use for injectable platform/environment information.

Prefer it when:
- Code needs OS checks, environment variables, executable paths, or locale-like platform details.
- Tests need fake platform values.

Avoid custom code for:
- Direct scattered `Platform.isWindows`, `Platform.environment`, etc.

Common pairings:
- `platform` + `process`.
- `platform` + `path`.

### `universal_platform`

Use for platform checks in code that may run on web, mobile, and desktop.

Prefer it when:
- Shared Flutter code needs platform checks without importing `dart:io`.
- View/model layers need simple `isWeb`, `isAndroid`, `isIOS`, `isMacOS`, etc.

Avoid:
- Importing `dart:io Platform` in code that must compile for web.

Use `platform` for injectable command-line/server platform behavior; use `universal_platform` for broad Flutter/web-safe checks.

### `os_detect`

Use for operating system detection helpers when this package is already part of the chosen stack.

Prefer it when:
- Writing command-line tools that need concise OS checks.
- Keeping platform detection readable.

Caution:
- Do not use both `platform`, `universal_platform`, and `os_detect` in the same layer without a reason. Pick the abstraction that matches the target environment and testability needs.

## Async, streams, channels, pooling, retries, and timing

### `async`

Use for advanced asynchronous utilities.

Prefer it when:
- Coordinating multiple futures.
- Working with cancellable operations.
- Memoizing asynchronous work.
- Using stream queues or result wrappers.
- Avoiding manual `Completer` and `StreamController` complexity.

Common useful concepts:
- `CancelableOperation`
- `AsyncMemoizer`
- `FutureGroup`
- `StreamQueue`
- `Result`
- `DelegatingStream` / `DelegatingSink`

Avoid custom code for:
- One-off cancellation wrappers.
- Manually buffering stream events.
- Manually grouping futures.

### `stream_transform`

Use for stream transformations.

Prefer it when:
- Debouncing events.
- Throttling events.
- Combining or switching streams.
- Mapping stream values asynchronously.
- Handling event timing without fragile custom `Timer` code.

Common pairings:
- `stream_transform` + `watcher` for file event debounce.
- `stream_transform` + `http` for streaming downloads/uploads.
- `stream_transform` + `stream_channel` for message pipelines.

### `stream_channel`

Use for bidirectional communication based on a stream plus sink.

Prefer it when:
- Modeling two-way communication.
- Building protocol clients/servers.
- Wrapping WebSockets, isolates, standard input/output, or test channels.
- Creating testable transports.

Typical concept:
- `StreamChannel<T>` exposes a stream for incoming messages and a sink for outgoing messages.

Common pairings:
- `stream_channel` + `dart_mcp`.
- `stream_channel` + `shelf` or WebSocket transports.
- `stream_channel` + `async` for queues and cancellation.

### `pool`

Use for limiting concurrency.

Prefer it when:
- Running many async jobs but only allowing N at a time.
- Limiting file reads, HTTP requests, process executions, or code generation tasks.
- Avoiding API rate limits or resource exhaustion.

Avoid custom code for:
- Semaphore-like classes.
- Manual job queues for simple concurrency caps.

Common pairings:
- `pool` + `http` for bounded downloads.
- `pool` + `process` for bounded command execution.
- `pool` + `glob` for bounded file processing.

### `retry`

Use for retrying transient failures.

Prefer it when:
- HTTP requests may fail temporarily.
- File or process operations may fail due to timing.
- External tools or network operations need exponential backoff.

Avoid custom code for:
- Hand-written retry loops with inconsistent delays.

Caution:
- Retry only idempotent or safely repeatable work unless explicitly designed otherwise.
- Do not hide permanent validation or authentication failures behind retries.

### `clock`

Use for testable time.

Prefer it when:
- Code uses the current time.
- Tests should control time deterministically.
- Time-sensitive logic calculates expiration, cooldowns, timestamps, or deadlines.

Avoid:
- Calling `DateTime.now()` directly in business logic.

Common pairings:
- `clock` + `fake_async` for time-based tests.
- `clock` + `timezone` for timezone-aware logic.

### `fake_async`

Use for deterministic async and timer tests.

Prefer it when:
- Testing timers.
- Testing debounced or throttled streams.
- Testing future/microtask behavior.
- Testing timeouts without real waiting.

This should usually be a `dev_dependency`.

Common pairings:
- `fake_async` + `clock`.
- `fake_async` + `stream_transform`.
- `fake_async` + `matcher`.

### `timing`

Use for timing operations and lightweight performance measurement.

Prefer it when:
- Measuring phases in command-line tools.
- Reporting elapsed time for build, generation, scan, or download steps.
- Keeping timing output consistent.

Avoid custom code for:
- Repeated `Stopwatch` boilerplate spread throughout the codebase.

### `chunked_stream`

Use for reading streams in chunks and assembling streamed data safely.

Prefer it when:
- Handling streamed byte data.
- Reading HTTP responses or files incrementally.
- Avoiding memory spikes from loading everything eagerly.

Common pairings:
- `chunked_stream` + `http`.
- `chunked_stream` + `typed_data`.
- `chunked_stream` + `convert`.

## Parsing, scanning, text, and markup

### `yaml`

Use for YAML parsing.

Prefer it when:
- Reading `pubspec.yaml`, configuration files, package manifests, or tool settings.
- Preserving YAML-specific structures.

Avoid custom code for:
- Splitting YAML files line-by-line.
- Treating YAML as JSON.

Common pairings:
- `yaml` + `path` + `file` for tool configuration.
- `yaml` + `collection` for safe map/list handling.

### `markdown`

Use for Markdown parsing and Markdown-to-HTML conversion.

Prefer it when:
- Rendering Markdown documentation.
- Parsing generated docs.
- Building developer tools that inspect Markdown files.

Avoid custom code for:
- Regex-only Markdown parsing.
- Manual Markdown-to-HTML conversion.

Common pairings:
- `markdown` + `shelf` to serve generated documentation.
- `markdown` + `glob` to scan docs.

### `string_scanner`

Use for tokenizing and small parsers.

Prefer it when:
- Writing parsers for simple languages, directives, templates, or custom config formats.
- Scanning strings with position-aware errors.
- Avoiding fragile index arithmetic.

Avoid custom code for:
- Manual `substring` cursor parsers.
- Regex-only parsers that need useful error positions.

Common pairings:
- `string_scanner` + `source_span` if source spans are introduced later.
- `string_scanner` + `term_glyph` for readable command-line parser errors.

### `characters`

Use for Unicode-correct string handling.

Prefer it when:
- Counting user-visible characters.
- Truncating strings for display.
- Handling emojis, accents, and grapheme clusters.

Avoid:
- Using `string.length` for user-visible character counts.
- Splitting strings by UTF-16 code units when display correctness matters.

### `convert`

Use for encoders, decoders, and conversion pipelines.

Prefer it when:
- Working with JSON, UTF-8, hex, base64, or stream conversion.
- Creating codec pipelines.
- Avoiding ad hoc conversion helpers.

Common pairings:
- `convert` + `crypto`.
- `convert` + `typed_data`.
- `convert` + `http`.

### `term_glyph`

Use for terminal glyph portability.

Prefer it when:
- Printing command-line output with tree characters, bullets, checkmarks, or ASCII fallbacks.
- Supporting Windows terminals or environments where Unicode glyphs may not render correctly.

Avoid custom code for:
- Manual checks for whether to print Unicode or ASCII terminal symbols.

## Collections, graphs, binary data, matching, and utility basics

### `collection`

Use for collection helpers and equality.

Prefer it when:
- Comparing lists, maps, sets, or nested structures.
- Grouping, sorting, merging, or querying collections.
- Needing priority queues or iterable extensions.

Avoid custom code for:
- Deep equality.
- Repeated `firstWhere` helpers.
- Group-by logic.

Common useful concepts:
- `ListEquality`
- `MapEquality`
- `DeepCollectionEquality`
- `PriorityQueue`
- Iterable extension helpers.

### `graphs`

Use for graph algorithms and dependency ordering.

Prefer it when:
- Sorting dependency graphs.
- Detecting cycles.
- Traversing directed graphs.
- Modeling package/module/task dependency order.

Avoid custom code for:
- Topological sorting.
- Cycle detection.
- Graph traversal utilities.

Common pairings:
- `graphs` + `glob` for project graph discovery.
- `graphs` + `collection` for stable ordering and lookup helpers.

### `typed_data`

Use for typed byte buffers and efficient binary data handling.

Prefer it when:
- Working with `Uint8List`, byte buffers, views, and binary protocols.
- Avoiding unnecessary byte copies.
- Interoperating with APIs that expect typed byte lists.

Common pairings:
- `typed_data` + `convert`.
- `typed_data` + `crypto`.
- `typed_data` + `chunked_stream`.

### `matcher`

Use for test matchers.

Prefer it when:
- Writing readable unit test assertions.
- Creating custom matchers.
- Matching exceptions, collections, strings, and structured values.

This should usually be a `dev_dependency`.

Common pairings:
- `matcher` + `fake_async`.
- `matcher` + `collection` equality helpers.

### `basics`

Use for general-purpose helpers if this package is already approved in the project.

Prefer it when:
- It clearly replaces small, repeated extension/helper code.
- The helper improves readability without hiding important behavior.

Caution:
- Do not import broad utility packages just for one trivial helper.
- Prefer Dart core APIs when they are already clear.

## Code generation and developer tooling

### `code_builder`

Use for generating Dart code through structured builders instead of string concatenation.

Prefer it when:
- Generating classes, methods, constructors, fields, enums, extensions, or libraries.
- Emitting Dart from metadata, schemas, or source transformations.
- Writing code generators where formatting and syntax correctness matter.

Avoid custom code for:
- Large string templates containing Dart syntax.
- Manually managing imports and references when structured builders are better.

Common pairings:
- `code_builder` + `dart_style` if formatting is available in the project.
- `code_builder` + `yaml` for config-driven generation.
- `code_builder` + `graphs` for dependency-ordered generation.
- `code_builder` + `path` + `file` for writing generated outputs.

Caution:
- For tiny generated files, a simple template may be acceptable, but once code has imports, nested declarations, generics, docs, or annotations, prefer `code_builder`.

### `data_assets`

Use for build hooks that bundle data assets into Dart or Flutter applications.

Prefer it when:
- A package needs generated or bundled non-code data.
- Build hooks need to declare data assets as strings or bytes.
- Native/tooling workflows need assets available at build/runtime boundaries.

Caution:
- This is specialized build-hook infrastructure. Do not use it as a general file loader.

### `memory_usage`

Use for memory measurement or memory diagnostics when available.

Prefer it when:
- Building profiling tools.
- Tracking memory during large code generation, parsing, or data processing.
- Creating diagnostics for developer tooling.

Caution:
- Keep memory measurement out of hot production paths unless there is a clear diagnostic requirement.

### `native_stack_traces`

Use for translating or working with native stack traces.

Prefer it when:
- Symbolicating stack traces.
- Building crash diagnostics.
- Working with native compiled Dart stack information.

Caution:
- This is specialized. Do not use it for ordinary Dart exception formatting; prefer `stack_trace` for Dart stack chains.

### `stack_trace`

Use for better stack trace handling.

Prefer it when:
- Capturing async stack chains.
- Formatting readable traces.
- Folding or chaining traces across asynchronous boundaries.
- Improving error reporting in tools and servers.

Avoid custom code for:
- Manually parsing stack trace strings.
- Losing async error context.

Common concepts:
- `Chain`
- `Trace`
- `Frame`

Common pairings:
- `stack_trace` + `shelf` for cleaner server error logs.
- `stack_trace` + `args` for command-line error reporting.

## Command-line tools and terminal apps

### `args`

Use for command-line argument parsing.

Prefer it when:
- Building command-line interfaces.
- Supporting flags, options, commands, help text, defaults, and validation.

Avoid custom code for:
- Parsing `List<String> arguments` manually.
- Hand-written `--flag=value` parsing.

Common pairings:
- `args` + `io` for command-line tools.
- `args` + `process` for tools that call external commands.
- `args` + `term_glyph` for readable output.

### `io`

Also relevant for command-line tools. Use it for portable input/output helpers where it reduces direct `dart:io` boilerplate.

### `term_glyph`

Also relevant for command-line tools. Use it for terminal-safe symbols and glyphs.

## Identity, hashing, random values, slugs, and cryptography

### `uuid`

Use for UUID generation and parsing.

Prefer it when:
- Creating stable unique identifiers.
- Interoperating with systems expecting UUIDs.
- Avoiding custom random ID formats.

Caution:
- Use the UUID version appropriate for the project. Random UUIDs are not naturally sortable. Time-based or ordered identifiers may need a different strategy.

### `slugid`

Use for compact, URL-safe identifiers when UUID-like uniqueness is desired but shorter/string-safe IDs are useful.

Prefer it when:
- Creating IDs for URLs, filenames, human-copyable references, or compact public identifiers.
- Avoiding long canonical UUID strings.

Caution:
- Confirm collision and security requirements. Do not use compact IDs as secrets unless the package and generation settings meet the security need.

### `rnd`

Use for random data helpers if this package is approved and fits the project.

Prefer it when:
- The package provides clearer random generation utilities than custom code.
- Generating test data, sample data, or non-security identifiers.

Caution:
- For cryptographic randomness, prefer secure random APIs and validate that the package is suitable.
- Do not use ordinary random values for tokens, passwords, secrets, or security-sensitive identifiers.

### `crypto`

Use for hashing and HMAC-style cryptographic primitives.

Prefer it when:
- Computing SHA hashes.
- Verifying checksums.
- Creating HMAC signatures.
- Hashing streamed data.

Avoid custom code for:
- Hash algorithms.
- Manual digest formatting when helpers exist.

Common pairings:
- `crypto` + `convert` for hex/base64 formatting.
- `crypto` + `typed_data` for byte input.
- `crypto` + `chunked_stream` for hashing large streams.

Caution:
- Do not use fast hashes alone for password storage. Password storage needs a password hashing algorithm designed for that purpose.

## Time zones and dates

### `timezone`

Use for timezone-aware date/time calculations.

Prefer it when:
- Scheduling events across time zones.
- Converting times between named locations.
- Avoiding incorrect assumptions from local time or UTC alone.

Avoid custom code for:
- Hard-coded timezone offsets.
- Daylight saving time rules.

Common pairings:
- `timezone` + `clock` for testable time calculations.

Caution:
- Ensure timezone data is initialized correctly for the runtime target.

## Caching

### `neat_cache`

Use for caching if the project has selected this package.

Prefer it when:
- Reusing expensive computations.
- Caching fetched or parsed data.
- Avoiding repeated file scans or network calls.

Caution:
- Define cache invalidation rules clearly.
- Do not cache user-sensitive or permission-sensitive data without an explicit policy.
- For simple one-shot async memoization, consider `AsyncMemoizer` from `async` first.

## Model Context Protocol and agent tooling

### `dart_mcp`

Use for building Model Context Protocol clients and servers in Dart.

Prefer it when:
- Creating tools/resources/prompts for AI hosts.
- Connecting Dart services to MCP-compatible clients.
- Building local developer automation servers.
- Exposing project operations, code search, package metadata, or build actions to an AI agent.

Common pairings:
- `dart_mcp` + `stream_channel` for transport abstraction.
- `dart_mcp` + `shelf` for HTTP-style or server-side integration.
- `dart_mcp` + `args` for command-line MCP servers.
- `dart_mcp` + `json` via `dart:convert` / `convert` for protocol payloads.

Caution:
- Treat this area as fast-moving. Check package APIs before assuming stability.
- Keep tool boundaries safe: validate inputs, restrict file access, and avoid exposing destructive operations by default.

## Package-specific quick reference table

| Package | Use instead of custom code for | Good fit | Usually avoid when |
|---|---|---|---|
| `shelf` | HTTP server abstractions and middleware | APIs, local servers, tool servers | Raw socket/protocol work is required |
| `mime` | MIME lookup | Static files, uploads | Content type is fixed and trivial |
| `stack_trace` | Async trace chains and formatting | Error reporting | Native stack symbolication is needed |
| `code_builder` | Dart code emission | Generators/transpilers | Tiny one-off text file generation |
| `yaml` | YAML parsing | Config, pubspecs | Data is actually JSON |
| `markdown` | Markdown parsing/rendering | Docs, generated HTML | Plain text only |
| `string_scanner` | Cursor-based scanning | Small parsers | Full grammar/parser generator needed |
| `graphs` | Graph algorithms | Dependency sorting/cycles | Simple list processing is enough |
| `io` | Portable command-line I/O helpers | CLI tools | Direct core API is clearer |
| `file` | File system abstraction | Testable file access | Throwaway scripts |
| `stream_transform` | Stream transforms | debounce/throttle/async mapping | Simple `map` is enough |
| `watcher` | File watching | rebuild/reload tools | One-time file scans |
| `pool` | Concurrency limits | bounded parallel jobs | Work is strictly sequential |
| `glob` | Glob matching | include/exclude file rules | Single known file path |
| `clock` | Testable current time | business logic with time | UI-only timestamp display with no tests |
| `process` | Testable process execution | CLI tools invoking commands | No external process use |
| `stream_channel` | Bidirectional stream/sink channels | protocols, WebSockets, isolates | One-way stream only |
| `term_glyph` | Terminal-safe glyphs | CLI output | No terminal output |
| `timing` | Timing measurements | build/tool diagnostics | No performance reporting |
| `native_stack_traces` | Native stack trace handling | crash/symbolication tooling | Normal Dart exceptions |
| `http` | HTTP client calls | REST/download/upload | Low-level transport required |
| `path` | Path manipulation | all file path code | Never hand-concatenate paths |
| `characters` | Unicode-safe text units | display text, truncation | byte/code-unit protocol parsing |
| `convert` | Encoding/decoding | JSON, UTF-8, base64, hex | Built-in direct API is already enough |
| `platform` | Injectable platform info | testable CLI/server code | Flutter web-safe checks are needed |
| `async` | Async coordination | cancellation, queues, memoization | Simple `await` is enough |
| `args` | CLI parsing | commands/options/help | No CLI surface |
| `fake_async` | Deterministic async tests | timers, debounce, timeouts | Runtime production code |
| `collection` | Collection utilities/equality | grouping, deep equality | Core collection API is enough |
| `matcher` | Test assertions | readable tests | Production runtime code |
| `typed_data` | Efficient binary data | bytes/protocols/hashing | Ordinary strings/objects |
| `os_detect` | OS detection helpers | concise CLI OS checks | Need injectable platform abstraction |
| `retry` | Retry/backoff | transient failures | Non-repeatable operations |
| `basics` | General helpers | repeated utility patterns | One trivial helper only |
| `chunked_stream` | Chunked stream reading | large files/responses | Small in-memory data |
| `slugid` | Compact URL-safe IDs | public references | Strict UUID compatibility required |
| `neat_cache` | Caching | expensive repeated work | No invalidation policy |
| `uri` | URI utilities | complex URL/URI handling | `dart:core Uri` is enough |
| `http_methods` | HTTP method constants | routers/clients | One local literal is clearer |
| `uuid` | UUIDs | stable unique IDs | Need sortable IDs by default |
| `crypto` | Hashes/HMAC/checksums | signatures, digests | Password hashing by itself |
| `timezone` | Named timezone logic | scheduling | UTC-only logic is sufficient |
| `dart_mcp` | MCP clients/servers | AI tools/resources/prompts | Ordinary HTTP API only |
| `data_assets` | Build-hook data assets | bundling generated data | General runtime file loading |
| `memory_usage` | Memory diagnostics | profiling/tools | Normal app logic |
| `universal_platform` | Web-safe platform checks | Flutter shared code | Injectable CLI platform abstraction needed |
| `rnd` | Random helpers | sample/test/non-secret IDs | Security-sensitive randomness |

## Common recipes

### Testable file-processing command-line tool

Prefer:
- `args` for command parsing.
- `file` for file system abstraction.
- `path` for path operations.
- `glob` for include/exclude patterns.
- `pool` for bounded parallel file processing.
- `watcher` and `stream_transform` for watch mode.
- `term_glyph` for readable terminal output.
- `stack_trace` for clean error output.

Do not hand-roll argument parsing, path joins, glob expansion, or concurrency queues.

### HTTP API or local developer server

Prefer:
- `shelf` for server and middleware.
- `mime` for content types.
- `http_methods` for method constants.
- `path` and `file` for static file access.
- `stack_trace` for error logs.

Do not build a custom middleware pipeline unless there is a clear reason.

### API client with robust networking

Prefer:
- `http` for requests.
- `retry` for transient failures.
- `convert` for JSON/UTF-8.
- `crypto` if signing or checksums are needed.
- `clock` for testable expiration/deadline logic.

Do not scatter raw HTTP calls through business logic; wrap an injected `Client`.

### Code generator or transpiler

Prefer:
- `code_builder` for Dart output.
- `yaml` for generator config.
- `graphs` for dependency ordering.
- `path` and `file` for output paths.
- `collection` for equality/grouping.
- `timing` and `memory_usage` for diagnostics.

Do not generate complex Dart with string concatenation.

### Stream-based protocol or agent transport

Prefer:
- `stream_channel` for bidirectional transport.
- `async` for queues, cancellation, and coordination.
- `stream_transform` for message stream transforms.
- `typed_data` and `convert` for binary/text encoding.
- `dart_mcp` when the protocol is Model Context Protocol.

Do not manually juggle paired stream controllers unless the package abstractions do not fit.

### Time-sensitive business logic

Prefer:
- `clock` instead of direct current time access.
- `timezone` for named timezone rules.
- `fake_async` for tests.

Do not hard-code timezone offsets or sleep in tests.

## Cautions for AI-generated code

- Do not add every package to every project. Select only what is needed for the feature.
- Do not use abandoned or obscure packages for critical paths without checking project acceptance.
- Do not duplicate capabilities. Example: pick one platform abstraction for a layer.
- Do not use production dependencies for test-only helpers.
- Do not hide complexity behind helpers when a standard Dart API is clearer.
- Do not import `dart:io` into code that must compile for web.
- Do not use random IDs or hashes as security features unless the security model is explicit.
- Do not parse structured formats with regular expressions when a parser package is available.

## Default dependency choices by problem

- Need HTTP server: `shelf`.
- Need HTTP client: `http`.
- Need file paths: `path`.
- Need testable files: `file`.
- Need YAML: `yaml`.
- Need Markdown: `markdown`.
- Need CLI args: `args`.
- Need stream debounce/throttle: `stream_transform`.
- Need two-way stream protocol: `stream_channel`.
- Need async cancellation/memoization/queues: `async`.
- Need bounded concurrency: `pool`.
- Need retries: `retry`.
- Need fake time in tests: `fake_async` + `clock`.
- Need graph dependency ordering: `graphs`.
- Need generate Dart code: `code_builder`.
- Need Unicode display-safe string logic: `characters`.
- Need collection equality/grouping: `collection`.
- Need binary buffers: `typed_data`.
- Need hashing/HMAC: `crypto`.
- Need UUIDs: `uuid`.
- Need compact URL-safe IDs: `slugid`.
- Need timezone rules: `timezone`.
- Need MCP: `dart_mcp`.

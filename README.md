## :lizard: :fox_face: **githunt**

[![CI][ci-shield]][ci-url]
[![License][license-shield]][license-url]

### Thread-pool-based Hacker News GitHub links reporter.

#### :rocket: Usage

1. Add `githunt` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_package>",
        .version = "<version_of_your_package>",
        .dependencies = .{
            .githunt = .{
                .url = "https://github.com/tensorush/githunt/archive/<git_tag_or_commit_hash>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    Set `<package_hash>` to `12200000000000000000000000000000000000000000000000000000000000000000`, and Zig will provide the correct found value in an error message.

    </details>

2. Add `githunt` as a run artifact in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const githunt = b.dependency("githunt", .{});
    const githunt_run = b.addRunArtifact(githunt.artifact("githunt"));
    ```

    </details>

<!-- MARKDOWN LINKS -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/githunt/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/githunt/blob/main/.github/workflows/ci.yaml
[license-shield]: https://img.shields.io/github/license/tensorush/githunt.svg?style=for-the-badge&labelColor=black&kill_cache=1
[license-url]: https://github.com/tensorush/githunt/blob/main/LICENSE.md

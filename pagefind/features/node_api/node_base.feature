Feature: Node API Base Tests
    Background:
        Given I have a "public/index.html" file with the body:
            """
            <p data-url>Nothing</p>
            """
        Given I have a "public/package.json" file with the content:
            """
            {
                "name": "test",
                "type": "module",
                "version": "1.0.0",
                "main": "index.js",
                "dependencies": {
                    "pagefind": "file:{{humane_cwd}}/../wrappers/node"
                }
            }
            """

    @platform-unix
    Scenario: Build a synthetic index to disk via the api
        Given I have a "public/index.js" file with the content:
            """
            import * as pagefind from "pagefind";

            const run = async () => {
                const { index } = await pagefind.createIndex();
                await index.addHTMLFile({path: "dogs/index.html", content: "<html><body><h1>Testing, testing</h1></body></html>"});
                await index.writeFiles();
                console.log(`Successfully wrote files`);
            }

            run();
            """
        When I run "cd public && npm i && PAGEFIND_BINARY_PATH='{{humane_cwd}}/../target/release/pagefind' node index.js"
        Then I should see "Successfully wrote files" in stdout
        Then I should see the file "public/_pagefind/pagefind.js"
        When I serve the "public" directory
        When I load "/"
        When I evaluate:
            """
            async function() {
                let pagefind = await import("/_pagefind/pagefind.js");

                let search = await pagefind.search("testing");

                let data = await search.results[0].data();
                document.querySelector('[data-url]').innerText = data.url;
            }
            """
        Then There should be no logs
        Then The selector "[data-url]" should contain "/dogs/"

    @platform-unix
    Scenario: Build a synthetic index to memory via the api
        Given I have a "public/index.js" file with the content:
            """
            import * as pagefind from "pagefind";

            const run = async () => {
                const { index } = await pagefind.createIndex();
                await index.addHTMLFile({path: "dogs/index.html", content: "<html><body><h1>Testing, testing</h1></body></html>"});
                const { files } = await index.getFiles();

                const jsFile = files.filter(file => file.path.includes("pagefind.js"))[0];
                console.log(jsFile.content.toString());

                const fragments = files.filter(file => file.path.includes("fragment"));
                console.log(`${fragments.length} fragment(s)`);
            }

            run();
            """
        When I run "cd public && npm i && PAGEFIND_BINARY_PATH='{{humane_cwd}}/../target/release/pagefind' node index.js"
        Then I should see "pagefind_version=" in stdout
        Then I should see "1 fragment(s)" in stdout
        Then I should not see the file "public/_pagefind/pagefind.js"

    @platform-unix
    Scenario: Build a true index to disk via the api
        Given I have a "public/custom_files/real/index.html" file with the body:
            """
            <p>A testing file that exists on disk</p>
            """
        Given I have a "public/index.js" file with the content:
            """
            import * as pagefind from "pagefind";

            const run = async () => {
                const { index } = await pagefind.createIndex();
                await index.addDirectory({path: "custom_files"});
                await index.writeFiles();
                console.log(`Successfully wrote files`);
            }

            run();
            """
        When I run "cd public && npm i && PAGEFIND_BINARY_PATH='{{humane_cwd}}/../target/release/pagefind' node index.js"
        Then I should see "Successfully wrote files" in stdout
        Then I should see the file "public/_pagefind/pagefind.js"
        When I serve the "public" directory
        When I load "/"
        When I evaluate:
            """
            async function() {
                let pagefind = await import("/_pagefind/pagefind.js");

                let search = await pagefind.search("testing");

                let data = await search.results[0].data();
                document.querySelector('[data-url]').innerText = data.url;
            }
            """
        Then There should be no logs
        Then The selector "[data-url]" should contain "/real/"

    @platform-unix
    Scenario: Build a blended index to memory via the api
        Given I have a "public/custom_files/real/index.html" file with the body:
            """
            <p>A testing file that exists on disk</p>
            """
        Given I have a "public/index.js" file with the content:
            """
            import * as pagefind from "pagefind";
            import fs from "fs";
            import path from "path";

            const run = async () => {
                const { index } = await pagefind.createIndex();
                await index.addDirectory({ path: "custom_files" });
                await index.addCustomRecord({
                    url: "/synth/",
                    content: "A testing file that doesn't exist.",
                    language: "en"
                });
                const { files } = await index.getFiles();

                for (const file of files) {
                    const dir = path.dirname(file.path);
                    if (!fs.existsSync(dir)){
                        fs.mkdirSync(dir, { recursive: true });
                    }

                    fs.writeFileSync(file.path, file.content);
                }
                console.log("Donezo!");
            }

            run();
            """
        When I run "cd public && npm i && PAGEFIND_BINARY_PATH='{{humane_cwd}}/../target/release/pagefind' node index.js"
        Then I should see "Donezo!" in stdout
        Then I should see the file "public/_pagefind/pagefind.js"
        When I serve the "public" directory
        When I load "/"
        When I evaluate:
            """
            async function() {
                let pagefind = await import("/_pagefind/pagefind.js");

                let search = await pagefind.search("testing");

                let pages = await Promise.all(search.results.map(r => r.data()));
                document.querySelector('[data-url]').innerText = pages.map(p => p.url).sort().join(", ");
            }
            """
        Then There should be no logs
        Then The selector "[data-url]" should contain "/real/, /synth/"

    @platform-unix
    Scenario: Build an index to a custom disk location via the api
        Given I have a "output/index.html" file with the body:
            """
            <p data-url>Nothing</p>
            """
        Given I have a "public/index.js" file with the content:
            """
            import * as pagefind from "pagefind";

            const run = async () => {
                const { index } = await pagefind.createIndex();
                await index.addHTMLFile({path: "dogs/index.html", content: "<html><body><h1>Testing, testing</h1></body></html>"});
                await index.writeFiles({ bundlePath: "../output/_pagefind" });
                console.log(`Successfully wrote files`);
            }

            run();
            """
        When I run "cd public && npm i && PAGEFIND_BINARY_PATH='{{humane_cwd}}/../target/release/pagefind' node index.js"
        Then I should see "Successfully wrote files" in stdout
        Then I should see the file "output/_pagefind/pagefind.js"
        When I serve the "output" directory
        When I load "/"
        When I evaluate:
            """
            async function() {
                let pagefind = await import("/_pagefind/pagefind.js");

                let search = await pagefind.search("testing");

                let data = await search.results[0].data();
                document.querySelector('[data-url]').innerText = data.url;
            }
            """
        Then There should be no logs
        Then The selector "[data-url]" should contain "/dogs/"

# Relic documentation website

This is the code for Relic's official documentation. You can view the updated documentation by choosing the _Next_ option in the top menu bar.

### Install

Make sure that you have Node.js installed on your computer.

```bash
brew install node
```

Run `npm install` from the docs directory:

```bash
cd docs
npm install
```

### Local Development

```bash
npm start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Add version

Make sure that the documentation is all up-to-date then run:

```bash
npm run docusaurus docs:version X.X.X
```

### Amend the latest version

If you need to make changes to the latest version, you can do so by removing the latest version from `versions.json` and adding it again running the create version command with the same version number.

```bash
npm run docusaurus docs:version X.X.X
```

### Add redirects

To maintain link integrity when relocating or renaming documentation pages, it's recommended to implement redirects. This is facilitated by the `@docusaurus/plugin-client-redirects` plugin. Redirects can be configured in the `docusaurus.config.js` file, within the `redirects` section of the plugin configuration.

### Deploy

Once a PR is merged into the `main` branch of this repository, a GitHub action is triggered that builds and deploys the documentation to Github pages. The documentation is available at `https://miniature-fortnight-wgn2qnl.pages.github.io`.

### Formatting

To ensure consistent formatting, we use markdownlint [(VS Code Extension)](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)

Install the `markdownlint-cli` globally, by running the following command from your terminal:

```bash
$ npm install -g markdownlint-cli
```

Formatting is only enforced in `/doc/site/` directory so therefore you only need to run the markdownlint-cli in this folder with:

```bash
$ markdownlint './doc/site/**/*.md'
```

### Force deploy from branch

This is useful if you want to deploy the branch you are working on to the documentation site but should in general never be used.

Follow these steps to deploy a specific branch:

1. Push your changes to the branch you are working on.
2. In github, go to the settings tab for the `serverpod_cloud` repository.
3. On the left side menu, click on `Environments`.
4. Select `github-pages` from the list`.
5. Add your branch to the list of branches that can deploy to github pages. (Only `main` is allowed by default).
6. Open `.github/workflows/deploy-documentation.yml` and change the branch from `main` to the branch you want to deploy from.
7. Push the changes to the repository.

Once the changes are pushed, the documentation will be deployed to the documentation site.

Once you are done, remember to remove the branch from the list of branches that can deploy to github pages and change the branch in the `deploy-documentation.yml` file back to `main`.

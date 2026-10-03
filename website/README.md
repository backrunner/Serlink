# Serlink official website

A custom product website and usage guide built with **svedocs 0.2.2** and Svelte 5.
The canonical domain is **https://serlink.alkinum.com**. Support uses
**support@serlink.alkinum.com**. The domain and email address are configuration;
a local build does not establish live hosting or mailbox delivery.

The site has English, Simplified Chinese and Japanese translations, a responsive
product screenshot gallery, local browser search, and light/dark/system themes.
It includes release availability, support, privacy and license pages, plus guides
for hosts, terminals, SFTP, vault recovery, sync and macOS MCP access.

## Develop and validate

Use Node 24 LTS or newer and the package manager pinned in `package.json`.
TypeScript is constrained to 6.x. Package versions were verified against the
registry on 2026-09-30; use the checked-in lockfile for reproducible installs.

```sh
cd website
pnpm install --frozen-lockfile
pnpm dev
pnpm check
pnpm check:docs
pnpm build
pnpm exec playwright install chromium
pnpm test
pnpm check:deploy
```

`pnpm preview:static` serves the built assets locally with the production routing
configuration. `pnpm preview` uses the SvelteKit preview server.

`pnpm build` produces a fully static site in `build/`. `pnpm check:docs` strictly
checks translations, content links and referenced assets. Browser tests run
against the Cloudflare local static-assets server at port 4189; they cover desktop and mobile in all
three languages, search scoping and keyboard operation, theme persistence,
language switching with translated fragments, code copying, 404 navigation and
static discovery endpoints. Screenshots are saved under ignored `test-results/`.

## Structure

- `svedocs.config.ts`: typed site metadata, i18n, navigation, SEO and local search.
- `vite.config.ts`: replacement theme registrations.
- `src/lib/Landing.svelte`: custom homepage composed through the `DocsApp` landing slot.
- `src/lib/theme/`: custom navbar, locale menu, footer, sidebar, article, standalone
  page/error shell and theme control. Framework search and outline behavior retain
  their controllers, with site-owned visual styling.
- `src/lib/site.css`: shared light/dark tokens and responsive landing/docs styling.
- `src/lib/messages.ts`: all visible custom UI text and localized shell labels.
- `content/pages/{en,zh,ja}/`: home, download, support, privacy and license pages.
- `content/docs/{en,zh,ja}/`: eight guides per language.
- `static/screenshots/`: actual Flutter application screenshots with fictional
  example data, from the reviewed macOS release-material set.
- `static/og.svg` and `og.png`: source and raster version of the social card.

English routes use `/` and `/docs/`; translated pages use `/zh/` and `/ja/`, while
translated docs use `/docs/zh/` and `/docs/ja/`, following svedocs' routing contract.
All internal UI links resolve through the current locale. Language switching
preserves query parameters and maps section fragments using the matching
translation's heading structure. Keep section order and depth aligned when
editing translations.

The site imports `svedocs/theme/base.css`, keeping accessibility and prose/code
structure, and supplies its own component layout and style tokens. It preserves
framework SEO, canonical/hreflang metadata, real Markdown rendering, local search,
`/sitemap.xml`, `/robots.txt`, `/llms.txt`, `/llms-full.txt` and each page's
`index.md` twin. Search has no hosted API, AI binding, user token or remote model.
Fonts use the system stack. There is no analytics integration or contact form;
the support page provides email and public issue links.

## Copy and visual style

Name features directly and describe concrete actions in every language. Keep
selection and focus styles tied to real interaction state. Avoid decorative
status dots, numbered section labels, badge strips, all-caps overlines and
repeated slogans. Use normal punctuation in Chinese instead of dot-separated
phrases. Apply the same wording to page metadata and the social card.

## Deployment

`wrangler.jsonc` describes a Cloudflare Workers static-assets deployment using
the `serlink.alkinum.com` custom domain, HTTPS, trailing-slash HTML handling and a
static 404 page. The production site has no runtime bindings. The dry run is a
configuration/bundle check and does not publish the website or configure DNS.

When publishing is requested, use the account authorized for `alkinum.com`:

```sh
pnpm run deploy
```

The deploy script checks types and content, rebuilds static output, and invokes
`wrangler deploy --no-autoconfig`. After deploying, verify live HTTPS, all three
languages, search, privacy/support links, robots/sitemap and the 404 response.
The App Store material pack points to `/support/` and `/privacy/`; establish their
public reachability before submitting those fields. Mailbox provisioning and
email-delivery verification remain independent from website deployment.

Do not add an App Store badge or installer URL until the corresponding public
release exists. Change the availability copy and platform status together across
all three translations when release gates have actually been completed.

## 中文说明

官网使用独立定制的首页与文档主题，包含中、英、日三语、真实应用截图切换、
本地搜索、深浅主题、支持、隐私、许可及功能指南。域名配置为
`serlink.alkinum.com`，支持邮箱为 `support@serlink.alkinum.com`。
构建与部署预演通过不代表网站已上线，也不代表邮箱已经开通。
公开安装包或商店页面出现后，再同步修改三种语言的发行状态。

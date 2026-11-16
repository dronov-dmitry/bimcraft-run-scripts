# Фронтенд доставки плагина

Папка самодостаточна для публикации на **GitHub Pages**: статика без сборки, без
зависимостей и без Node.js. **Это и есть корень git-репозитория для GitHub**:
`scripts/publish-pages.py` инициализирует репозиторий здесь, а не в `delivery/`,
поэтому бэкенд и корневые файлы в GitHub не попадают.

```
frontend/            ← корень git-репозитория; в GitHub уходит только он
  public/            ← артефакт GitHub Pages, публикуется как есть
    index.html
    404.html         GitHub Pages отдаёт его на несуществующие адреса
    styles.css
    app.js           читает манифест у бэкенда, ничего не собирает
    config.js        адрес бэкенда и ссылка на репозиторий; пишет scripts/publish-back.py
    favicon.svg
    robots.txt
    .nojekyll        отключает обработку Jekyll
  tools/preview.mjs  локальный просмотр; в публикацию не входит
  .github/workflows/ pages.yml — единственный workflow репозитория
  README.md
```

## Как публикуется

`.github/workflows/pages.yml` внутри этой папки на каждый push в `main`,
затрагивающий `public/**`:

1. проверяет, что в `public/` есть обязательные файлы и нет файлов разработки;
2. загружает `public/` артефактом Pages;
3. деплоит.

В настройках репозитория должно стоять **Settings → Pages → Source: GitHub Actions**.
`scripts/publish-pages.py` включает это через `gh api`, если `gh` авторизован.

Адрес проекта: `https://<owner>.github.io/<repo>/`. Все ссылки в странице
**относительные** — иначе на project pages они уйдут в корень домена и получат 404.

Бэкенд (`delivery/backend`) в этом репозитории отсутствует: он деплоится локально
через `scripts/publish-back.sh`.

## Локальный просмотр

```bash
pnpm frontend:dev      # из delivery/, http://127.0.0.1:4173
```

Для проверки против локального бэкенда поставьте в `public/config.js`
`workerBase: "http://127.0.0.1:8787"` и запустите `pnpm backend:dev`.
Страница понимает и `http`, и `https`.

## `config.js`

Единственный файл, который меняется при развёртывании:

```js
window.BIMCRAFT_DELIVERY = {
  workerBase: "https://<worker>.<subdomain>.workers.dev",
  repository: "https://github.com/<owner>/<repo>",
};
```

Его перезаписывает `scripts/publish-back.py` после деплоя бэкенда. Релиз плагина этот файл
не трогает: версии и digest приходят из `/v1/manifest.json`.

## Правила

- Сюда не добавлять: Node-код, сборку, `node_modules`, карты исходников, секреты и
  адреса, которые нельзя публиковать.
- Никаких абсолютных путей (`/styles.css`): сайт живёт в подпапке.
- Данные из сети рендерятся только через `textContent` — `app.js` не собирает HTML
  из ответа бэкенда.
- Скрипты развёртывания живут **вне** этой папки: `../../scripts/`.

## Свой домен

1. Положить `CNAME` в `public/` с одним доменом в первой строке.
2. Настроить DNS у регистратора (для apex — `A`/`AAAA` на адреса GitHub Pages, для
   поддомена — `CNAME` на `<owner>.github.io`).
3. **Settings → Pages → Custom domain**, включить HTTPS.

Файл `CNAME` публикуется вместе с сайтом; без настроенного домена его добавлять нельзя.

## Чек-лист перед публикацией

- [ ] `public/index.html`, `public/404.html`, `public/config.js` не пустые;
- [ ] `config.js` содержит реальный адрес бэкенда, а не `example.workers.dev`;
- [ ] в `public/` нет `.map`, `node_modules`, `.ts`;
- [ ] ссылки относительные;
- [ ] `404.html` открывается и ведёт на `./`;
- [ ] страница в тёмной и светлой теме читается (цвета через `prefers-color-scheme`).

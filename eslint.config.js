const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  js.configs.recommended,
  {
    files: ['app/javascript/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: { ...globals.browser, require: 'readonly', process: 'readonly' },
    },
    rules: { 'no-console': 'error' },
  },
];

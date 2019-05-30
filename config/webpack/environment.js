const I18nLoader = require('./i18n_loader');
const VirtualModulePlugin = require("virtual-module-webpack-plugin");
const path = require('path');
const webpack = require('webpack')
const { environment } = require('@rails/webpacker')

environment.loaders.delete('nodeModules')
environment.loaders.get('sass').use.splice(-1, 0, {
  loader: 'resolve-url-loader',
  options: {
    debug: false,
  }
});
environment.plugins.append('translations', new VirtualModulePlugin({
  moduleName: './app/javascript/i18n.json',
  contents: JSON.stringify(new I18nLoader(path.resolve(__dirname, "../locales/")).fetch()),
}));

module.exports = environment

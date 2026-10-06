const path = require('path');
const { generateWebpackConfig } = require('shakapacker');
const VirtualModulesPlugin = require('webpack-virtual-modules');
const I18nLoader = require('./i18n_loader');

const webpackConfig = generateWebpackConfig({
  plugins: [
    new VirtualModulesPlugin({
      './app/javascript/i18n.json': JSON.stringify(
        new I18nLoader(path.resolve(__dirname, '../locales/')).fetch(),
      ),
    }),
  ],
});

module.exports = webpackConfig;

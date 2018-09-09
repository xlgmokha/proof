const { environment } = require('@rails/webpacker')
const RailsTranslationsPlugin = require("rails-translations-webpack-plugin");
const path = require('path');
const webpack = require('webpack')

environment.loaders.append('json', { test: /\.json$/, use: ['json-loader'] });
environment.plugins.prepend('RailsTranslationsPlugin', new RailsTranslationsPlugin({
  localesPath: path.resolve(__dirname, "../locales/"),
  root: './app/javascript'
}))
environment.plugins.append(
  'Provide',
  new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    'window.jQuery': 'jquery',
  })
)

module.exports = environment

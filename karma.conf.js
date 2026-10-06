// Karma configuration
// Generated on Sun Jan 28 2018 13:49:43 GMT-0700 (MST)

const webpackConfig = require('./config/webpack/webpack.config.js');

module.exports = function(config) {
  const tests = 'spec/javascripts/**/*.spec.js';
  config.set({
    basePath: '',
    frameworks: ['jasmine', 'fixture'],
    files: [
      tests,
      'spec/fixtures/**/*.html',
      'spec/fixtures/**/*.json',
      'node_modules/jquery/dist/jquery.min.js',
    ],
    exclude: [ ],
    preprocessors: {
      'app/javascript/packs/*.js': ['webpack', 'sourcemap'],
      '**/*.html': ['html2js'],
      '**/*.json': ['json_fixtures'],
      [tests]: ['webpack', 'sourcemap']
    },
    reporters: ['mocha'],
    mochaReporter: {
      output: 'autowatch'
    },
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: [process.env.CI || process.env.KARMA_NO_SANDBOX ? 'ChromeHeadlessNoSandbox' : 'ChromeHeadless'],
    singleRun: true,
    concurrency: Infinity,
    customLaunchers: {
      ChromeHeadlessNoSandbox: {
        base: 'ChromeHeadless',
        flags: ['--no-sandbox', '--disable-dev-shm-usage'],
      },
    },
    webpack: Object.assign({}, webpackConfig, {
      entry: undefined,
      devtool: 'inline-source-map',
      optimization: { splitChunks: false, runtimeChunk: false },
      plugins: webpackConfig.plugins.filter(
        (plugin) => !['WebpackAssetsManifest', 'MiniCssExtractPlugin'].includes(plugin.constructor.name),
      ),
    }),
    webpackMiddleware: {
      stats: 'errors-only'
    }
  })
}

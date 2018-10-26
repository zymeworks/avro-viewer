const es = require('event-stream');
const gulp = require('gulp');
const rmrf = require('gulp-rimraf');
const lessc = require('gulp-less');
const rename = require('gulp-rename');

gulp.task('clean', [], function() {
  return gulp.src("./build/*", { read: false }).pipe(rmrf());
});

gulp.task('build', ['clean'], function () {
  const templates = gulp.src('templates/*.html')
    .pipe(gulp.dest('./build'));

  const css = gulp.src("less/main.less")
    .pipe(lessc())
    .pipe(rename('styles.css'))
    .pipe(gulp.dest("./build/css"));

  const js = gulp.src('src/*.js')
    .pipe(gulp.dest('./build/js'));

  const vendor = gulp.src(['node_modules/file-saver/FileSaver.min.js',
                           'node_modules/font-awesome/css/font-awesome.min.css',
                           'node_modules/tachyons/css/tachyons.min.css',
                           'node_modules/font-awesome/fonts/*' ],
                          {base: 'node_modules/'})
    .pipe(gulp.dest('./build/vendor/node_modules'));

  const elmApp = gulp.src('bundle/elm-app.js')
    .pipe(gulp.dest('./build/js'));

  const avro = gulp.src('bundle/avro.js')
    .pipe(gulp.dest('./build/vendor'));

  return es.merge(templates, css, js, vendor, elmApp, avro);
});


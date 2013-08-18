module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    meta:
      src:
        server: 'lib'
        client: 'public/js/lib'
      build:
        server: 'lib'
        client: 'public/js'
        css:    'public/css'
      test: 'tests'

    coffee:
      server:
        files: [
          {
            'app.js': 'app.coffee'
          }, {
            expand: true
            cwd: '<%= meta.src.server %>'
            src: ['**/*.coffee']
            dest: '<%= meta.src.server %>'
            ext: '.js'
          }
        ]
      client:
        options:
          bare: false
        files: [
          {
            expand: true,
            cwd: '<%= meta.src.client %>'
            src: ['**/*.coffee']
            dest: '<%= meta.src.client %>'
            ext: '.js'
          }
        ]

    concat:
      options:
        separator: ";"
      vendor:
        src: [
          'bower_components/jquery/jquery.js'
          'bower_components/two/build/two.js'
          'bower_components/lodash/dist/lodash.js'
          'bower_components/backbone/backbone.js'
          'bower_components/hogan/web/builds/2.0.0/hogan-2.0.0.js'
          'bower_components/tweenjs/src/Tween.js'
          ],
        dest: "<%= meta.build.client %>/vendor.js"
      app:
        src: ["<%= meta.src.client %>/**/*.js"]
        dest: "<%= meta.build.client %>/app.js"

    uglify:
      options:
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("dd-mm-yyyy") %> */\n'
      app:
        files:
          '<%= meta.build.client %>/app.min.js': ['<%= concat.app.dest %>']
      vendor:
        files:
          '<%= meta.build.client %>/vendor.min.js': ['<%= concat.vendor.dest %>']

    watch:
      src_server:
        files: ['app.coffee', '<%= meta.src.server%>/**/*.coffee']
        tasks: ['coffee:server']
      src_client:
        files: ['<%= meta.src.client %>/**/*.coffee']
        tasks: ['coffee:client']

  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-watch')

  grunt.registerTask 'default', ['coffee', 'concat', 'uglify']
  grunt.registerTask 'server', ['coffee:server']
  grunt.registerTask 'client', ['coffee:client']
  
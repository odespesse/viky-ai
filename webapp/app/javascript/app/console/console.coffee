$ = require('jquery');
moment = require('moment');


class Console
  constructor: ->
    @timeout = null
    $('#js-console-now-input-container input').val(moment().format())

    $("body").on 'click', (event) => @dispatch(event)

    $("#js-console-form").on 'change', ':input', (event) =>
      $("#console-reset-btn").show()

    $("body").on 'console-select-now-type-auto', (event) =>
      $('#js-console-now-input-container').hide()
      $('#js-console-now-input-container input').val(moment().format())

    $("body").on 'console-select-now-type-manual', (event) =>
      $('#js-console-now-input-container').show()
      $("#console-reset-btn").show()

    $("body").on 'ajax:before', (event) =>
      if $(event.target).attr('id') == "js-console-form"
        if $(".console__output").hasClass('console__output__loading')
          $(".console__output").removeClass('console__output__loading')
          clearTimeout(@timeout) if @timeout

    $("body").on 'ajax:success', (event) =>
      if $(event.target).attr('id') == "js-console-form"
        $(".console__output").addClass('console__output__loading')
        @timeout = setTimeout ->
          $(".console__output").removeClass('console__output__loading')
        , 500
        $("#console-reset-btn").show()


  dispatch: (event) ->
    link = @get_link_target(event)
    action = link.data('action')

    if action == 'console-enter-fullscreen'
      event.preventDefault()
      $('#console-enter-fullscreen').hide()
      $('#console-leave-fullscreen').show()
      $(".console-container").addClass("console-container--fullscreen")
      $(".app-wrapper").addClass("app-wrapper--without-h-nav")
      $("main").hide()
      $("nav.h-nav").hide()
      $(".toggle-console").hide()
      App.FocusInput.atEnd("input[name='interpret[sentence]']")

    if action == 'console-leave-fullscreen'
      event.preventDefault()
      $('#console-enter-fullscreen').show()
      $('#console-leave-fullscreen').hide()
      $(".console-container").removeClass("console-container--fullscreen")
      $(".app-wrapper").removeClass("app-wrapper--without-h-nav")
      $("main").show()
      $("nav.h-nav").show()
      $(".toggle-console").show()
      $("body").trigger("console:leave-fullscreen")

    if action == 'console-explain-highlighted-word'
      event.preventDefault()
      $('.intent__highlight ul').hide()
      if $(event.target).hasClass('current')
        $('.intent__highlight match').removeClass('current')
      else
        $('.intent__highlight match').removeClass('current')
        $(event.target).addClass('current')
        $($(event.target).data('target')).show()

  get_link_target: (event) ->
    if $(event.target).is('a') || $(event.target).is('match')
      return $(event.target)
    else
      return $(event.target).closest('a')

Setup = ->
  if $('.console-container').length == 1
    new Console()

$(document).on('turbolinks:load', Setup)

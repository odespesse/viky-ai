$ = require('jquery');

class Modal
  constructor: ->
    $("body").on 'click', (event) => @dispatch(event)

  dispatch: (event) ->
    node   = $(event.target)
    action = node.data('action')

    if not action?
      node = $(event.target).closest('a')
      action = node.data('action')
    if not action?
      node = $(event.target).closest('button')
      action = node.data('action')

    if action is "open-modal"
      event.preventDefault()
      modal_selector =
      @prepare($(node.data('modal-selector')).clone())

    if action is "open-remote-modal"
      event.preventDefault()
      $.ajax
        url: node.attr('href')
        complete: (data) =>
          @prepare(data.responseText)
          $('body').trigger('modal:open')

    if action is "close-modal"
      event.preventDefault()
      @close()

  close: ->
    $('.app-wrapper').removeClass('modal-background-effect')
    $('.modal').hide()
    $(document).off 'keyup'

  prepare: (html_content) ->
    $("<div id='modal_container'></div>").appendTo('body') if ($('#modal_container').length == 0)
    $('#modal_container').html(html_content)
    $('#modal_container .modal').show()
    $('.app-wrapper').addClass('modal-background-effect')
    $(document).on 'keyup', (e) => @close() if e.keyCode == 27


Setup = ->
  new Modal()

$(document).on('turbolinks:load', Setup)

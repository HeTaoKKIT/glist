{File, Directory} = require 'atom'
{SelectListView} = require 'atom-space-pen-views'

_ = require('lodash-fp')
gistCache = null
filterQuery = null
ghgist = null
module.exports =
class GlistView extends SelectListView
  initialize: (client, state) ->
    super
    ghgist = client
    @addClass('overlay from-top')
    @setItems gistCache if gistCache
    @state = state

  attachList: ->
    @storeFocusedElement()
    @setLoading("Fetching All Gists...")
    @panel ?= atom.workspace.addModalPanel(item: this)
    ghgist.list (error, gists) =>
      indexedGists = _(gists).map (gist) ->
        gist.key = gist.description + " " + _.values(gist.files)
          .map (file)->
            file.filename
          .join ' '
        gist
      gistCache = indexedGists.value()
      gistCache.push {description: 'create new gist', key: 'create new add', files: {}}
      @setItems(gistCache) unless error
    @focusFilterEditor()

  viewForItem: (gist) ->
    "<li>
      <div>#{gist.description}</div>
      <div class='text-subtle'>#{_(gist.files).values().first()?.filename}</div>
    </li>"

  getFilterKey: ->
    "key"

  confirmed: (item) ->
    if item
      @setLoading("Opening gist #{item.id} #{item.description}...")
      gistPath = atom.config.get('glist.gistDir') + '/' + item.id + '/'
      ghgist.get item.id, (error, gist) ->
        if error
          atom.notifications.addError error
          @cancel()
        _.forEach (file, filename) ->
          gistfile = new File(gistPath + filename)
          gistfile.create().then ->
            gistfile.write(file.content).then ->
              atom.workspace.open(gistPath + filename)
              @cancel()
          .catch (e)->
            @cancel()
            atom.notifications.addError e
        , gist.files
      atom.project.addPath(atom.config.get('glist.gistDir'))
    else
      @cancel()

  confirmSelection: ->
    item = @getSelectedItem()
    if item?
      @confirmed(item)
    else
      @state.filterQuery = @getFilterQuery()
      atom.workspace.open(atom.config.get('glist.gistDir')+ '/.tmp/' +@state.filterQuery?.toLowerCase().replace(" ","-") + atom.config.get('glist.fileSuffix'))

  cancelled: ->
    @panel?.destroy()
    @panel = null

  destroy: ->
    @cancel()

  toggle: ->
    if @panel?
      @cancel()
    else
      @attachList()

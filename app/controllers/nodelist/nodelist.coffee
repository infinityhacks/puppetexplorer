angular.module("app").controller "NodeListCtrl", class
  constructor: (@$location, @$scope, @PuppetDB) ->
    # Reload nodes if either the page changes
    @$scope.$on('pageChange', @fetchNodes)
    # Reset pagination and reload nodes if query changes
    @$scope.$on('queryChange', @reset)
    @$scope.perPage = 50
    @$scope.page = 1
    @reset()

  reset: =>
    @$location.search('page', null)
    @$scope.numItems = undefined
    @fetchNodes()

  # Public: Fetch the list of nodes for the current query
  #
  # Returns: `undefined`
  fetchNodes: =>
    @nodes = undefined
    @PuppetDB.parseAndQuery(
      "nodes",
      @$location.search().query,
      null,
      {
        offset: @$scope.perPage * (@$scope.page - 1)
        limit: @$scope.perPage
        "order-by": angular.toJson([field: "certname", order: "asc"])
      },
      (data, total) =>
        @$scope.numItems = total
        @nodes = data
        for node in @nodes
          @fetchNodeStatus(node)
        if @$location.search().node?
          @fetchSelectedNode()
      )

  # Public: Fetch node status
  #
  # node - The {Object} node to fetch status for
  #
  # Returns: `undefined`
  fetchNodeStatus: (node) =>
    @PuppetDB.parseAndQuery(
      "event-counts"
      null
      ["and", ["=", "certname", node.certname], ["=", "latest-report?", true]],
        'summarize-by': 'certname'
        'order-by': angular.toJson([field: "certname", order: "asc"])
      do (node) ->
        (data, total) ->
          if data.length
            node.status = data[0]
          else # The node didn't have any events
            node.status =
              failures: 0
              skips: 0
              noops: 0
              successes: 0
      )

  # Public: Fetch facts for a node and store them in it
  #
  # node - The node {Object}
  #
  # Returns: `undefined`
  fetchNodeFacts: (node) =>
    return if node.facts?
    @PuppetDB.parseAndQuery(
      "facts"
      null
      ["=", "certname", node.certname],
        'order-by': angular.toJson([field: "name", order: "asc"])
      do (node) ->
        (data, total) ->
          node.facts = data.filter((fact) ->
            fact.name[0] isnt '_'
          ).map((fact) ->
            # insert some spaces to break lines
            fact.value = fact.value.replace(/(.{25})/g,"\u200B$1")
            fact
          )
      )

  # Public: Fetch the currently selected node
  #
  # Returns: `undefined`
  fetchSelectedNode: () =>
    for node in @nodes
      if node.certname == @$location.search().node
        @selectNode(node)


  # Public: Get the list of important facts to show in detail view
  #
  # Returns: A {Array} of important facts {String}.
  importantFacts: (node) ->
    node.facts.filter((fact) ->
      NODE_FACTS.indexOf(fact.name) != -1
    ).sort((a,b) -> NODE_FACTS.indexOf(a.name) - NODE_FACTS.indexOf(b.name))

  # Public: Select a node to show info for
  #
  # node - The node {Object}
  #
  # Returns: `undefined`
  selectNode: (node) =>
    if @selectedNode == node
      @$location.search('node', null)
      @selectedNode = null
    else
      @$location.search('node', node.certname)
      @selectedNode = node
      unless node.facts?
        @fetchNodeFacts(node)

  # Public: set the query to find a node and show events for it
  #
  # node - The {String} name of the node
  #
  # Returns: `undefined`
  showEvents: (node) ->
    @$location.search "query", "\"#{node}\""
    @$location.path "/events"

  # Public: Return the status of a node
  #
  # node - The {Object} node
  #
  # Returns: The {String} "failure", "skipped", "noop", "success" or "none"
  #          of `null` if no status known.
  nodeStatus: (node) ->
    return 'glyphicon-refresh spin' unless node.status
    return 'glyphicon-warning-sign text-danger' if node.status.failures > 0
    return 'glyphicon-exlamation-sign text-warning' if node.status.skips > 0
    return 'glyphicon-exlamation-sign text-info' if node.status.noops > 0
    return 'glyphicon-ok-sign text-success' if node.status.successes > 0
    return 'glyphicon-ok-sign text-muted'

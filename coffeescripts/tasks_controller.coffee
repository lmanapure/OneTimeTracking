###
Angular.js Popup Tasks Controller
###

app = angular.module 'hayfeverApp', [ 'ngAnimate' ]

tasks_controller = ($scope) ->
  # DEBUG MODE: set this to true to show debug content in popup
  $scope.debug_mode            = false

  $scope.form_visible          = false
  $scope.table_spinner_visible = false
  $scope.form_spinner_visible  = false
  $scope.runaway_timer         = false
  $scope.active_timer_id       = 0
  $scope.current_hours         = 0.0
  $scope.total_hours           = 0.0
  $scope.tasks                 = []
  $scope.storiesForProject     = []
  $scope.tasksForStory         = []
  $scope.form_task             =
    project: null
    task: null
    hours: null
    notes: null
    tpproject: null
    tpstory: null
    tptask: null
    tpremaining: null
  console.debug $scope.form_visible

  # Grab background application data
  chrome.runtime.sendMessage { method: 'get_entries' }, (resp) ->
    $scope.harvest_url   = resp.harvest_url
    $scope.authorized    = resp.authorized
    $scope.projects      = resp.projects
    $scope.clients       = resp.clients
    $scope.timers        = resp.timers
    $scope.prefs         = resp.preferences
    $scope.current_hours = resp.current_hours
    $scope.total_hours   = resp.total_hours
    $scope.current_task  = resp.current_task
    $scope.tpProjects    = resp.tpProjects
    $scope.theClient     = new TargetProcess(resp.tpClient.subdomain, resp.tpClient.auth_string)
    $scope.$apply()
    #console.debug "Response"
    #console.debug resp
    console.debug resp.projects

  $scope.refresh = ->
    $scope.table_spinner_visible = true

    chrome.runtime.sendMessage { method: 'refresh_hours' }, (resp) ->
      $scope.harvest_url   = resp.harvest_url
      $scope.authorized    = resp.authorized
      $scope.projects      = resp.projects
      $scope.clients       = resp.clients
      $scope.timers        = resp.timers
      $scope.current_hours = resp.current_hours
      $scope.prefs         = resp.preferences
      $scope.total_hours   = resp.total_hours
      $scope.current_task  = resp.current_task
      $scope.tpProjects    = resp.tpProjects
      $scope.theClient     = new TargetProcess(resp.tpClient.subdomain, resp.tpClient.auth_string)
      $scope.$apply()

    chrome.runtime.sendMessage { method: 'get_preferences' }, (resp) ->
      $scope.prefs                 = resp.preferences
      $scope.table_spinner_visible = false
      $scope.$apply()
  
  $scope.add_timer = ->
    $('#task-notes').trigger('change')
    #maybe need to scope digest here
    $scope.form_spinner_visible = true
    task =
      project_id: $scope.form_task.project
      task_id: $scope.form_task.task
      hours: $scope.form_task.hours
      notes: $scope.form_task.notes
      tpProject: $scope.form_task.tpproject
      tpStory: $scope.form_task.tpstory
      tpTask: $scope.form_task.tptask
      tpSpent: $scope.form_task.hours,
      tpRemaining: $scope.form_task.tpremaining
    chrome.runtime.sendMessage 
        method: 'add_timer'
        active_timer_id: $scope.active_timer_id
        task: task
        (resp) ->
            $scope.form_spinner_visible = false
            $scope.hide_form()
            $scope.refresh()
    return
  
  $scope.tp_project_change = ->
    $scope.form_spinner_visible = true
    $scope.storiesForProject = []
    $scope.tasksForStory = []
    tpClient = $scope.theClient
    tpStories = tpClient.getStories $scope.form_task.tpproject
    # projectTitle = $('#tp-project-select option:selected').val()
    $('#task-notes').val('#' + $scope.form_task.tpproject)
    tpStories.success (json) =>
        stories = json.Items
        $scope.storiesForProject.push({ Id: story.Id, Name: story.Name }) for story in stories
        $scope.form_spinner_visible = false
        $scope.$apply()
        return

  $scope.project_change = ->
    $scope.tasks = []
    current_project = _($scope.projects).find (p) -> p.id == parseInt($scope.form_task.project)
    tasks = current_project.tasks
    
    tasks.forEach (task) ->
      task.billable_text = if task.billable then 'Billable' else 'Non Billable'
      $scope.tasks.push task
  
  $scope.story_change = ->
    currentText = $('#task-notes').val()
    currentText = currentText.concat(' - #', $scope.form_task.tpstory)
    $('#task-notes').val(currentText)
    $scope.form_spinner_visible = true
    $scope.tasksForStory = []
    tpClient = $scope.theClient
    tpTasks = tpClient.getTasks $scope.form_task.tpstory
    #storyTitle = $('#tp-story-select option:selected').text()
    #currentText = currentText.concat(' - ', storyTitle)
    tpTasks.success (json) =>
        tasks = json.Items
        $scope.tasksForStory.push({ Id: task.Id, Name: task.Name }) for task in tasks
        $scope.form_spinner_visible = false
        $scope.$apply()
        return
  
  $scope.task_change = ->
      #taskTitle = $('#tp-task-select option:selected').text()
      currentText = $('#task-notes').val()
      #currentText = currentText.concat(' - ', taskTitle)
      currentText = currentText.concat(' - #', $scope.form_task.tptask)
      $('#task-notes').val(currentText)
      return
  
  $scope.toggle_timer = (timer_id) ->
    $scope.table_spinner_visible = true
    chrome.runtime.sendMessage { method: 'toggle_timer', timer_id: timer_id }, (resp) ->
      $scope.table_spinner_visible = false
      $scope.refresh()
  
  $scope.delete_timer = (timer_id) ->
    $scope.table_spinner_visible = true
    chrome.runtime.sendMessage { method: 'delete_timer', timer_id: timer_id }, (resp) ->
      $scope.table_spinner_visible = false
      $scope.refresh()
  
  $scope.stop_timer = (timer_id) =>
    $scope.table_spinner_visible = true
    $scope.refresh()
  
  $scope.show_form = (timer_id=0) ->
    $scope.active_timer_id = timer_id
    $scope.reset_form_fields()

    unless $scope.active_timer_id is 0
      timer = _($scope.timers).find (item) -> item.id == $scope.active_timer_id

      if timer
        $scope.form_task.project = parseInt timer.project_id, 10
        $scope.form_task.task = parseInt timer.task_id, 10
        $scope.form_task.hours = timer.hours
        $scope.form_task.notes = timer.notes
        $scope.project_change()
    
    $scope.form_visible = true
  
  $scope.hide_form = ->
    $scope.form_visible = false
    $scope.storiesForProject = []
  
  $scope.reset_form_fields = ->
    $scope.form_task =
      project: null
      task: null
      hours: null
      notes: null

  $scope.toggle_spinners = ->
    $scope.table_spinner_visible = !$scope.table_spinner_visible
    $scope.form_spinner_visible = !$scope.form_spinner_visible

clock_time_filter = ->
  (input) ->
    input.toClockTime()

app.controller 'TasksController', [ '$scope', tasks_controller ]
app.filter 'clockTime', clock_time_filter

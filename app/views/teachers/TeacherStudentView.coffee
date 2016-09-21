RootView = require 'views/core/RootView'
Campaigns = require 'collections/Campaigns'
Classroom = require 'models/Classroom'
Courses = require 'collections/Courses'
Levels = require 'collections/Levels'
LevelSession = require 'models/LevelSession'
LevelSessions = require 'collections/LevelSessions'
User = require 'models/User'
Users = require 'collections/Users'
CourseInstances = require 'collections/CourseInstances'
require 'vendor/d3'
# Users = require 'collections/Users'
# helper = require 'lib/coursesHelper'
# popoverTemplate = require 'templates/courses/classroom-level-popover'
# Prepaids = require 'collections/Prepaids'
# utils = require 'core/utils'
# CocoCollection = require 'collections/CocoCollection'



module.exports = class TeacherStudentView extends RootView
  id: 'teacher-student-view'
  template: require 'templates/teachers/teacher-student-view'
  # helper: helper
  events:
    'click .assign-student-button': 'onClickAssignStudentButton' # this button isn't working yet
    'click .enroll-student-button': 'onClickEnrollStudentButton' # this button isn't working yet
    'change #course-dropdown': 'onChangeCourseChart'



  getTitle: -> return @user?.broadName()

  initialize: (options, classroomID, @studentID) ->
    @classroom = new Classroom({_id: classroomID})
    @listenToOnce @classroom, 'sync', @onClassroomSync
    @supermodel.trackRequest(@classroom.fetch())

    @courses = new Courses()
    # @courses.comparator = '_id'
    # @courseInstances = new CocoCollection([], { url: "/db/course_instance", model: CourseInstance})
    # @courseInstances.comparator = 'courseID'
    # @supermodel.loadCollection(@courseInstances, { data: { classroomID: classroomID } })
    # @listenToOnce @courses, 'sync', @onCourseInstancesSync
    @supermodel.trackRequest(@courses.fetch({data: { project: 'name' }}))

    @courseInstances = new CourseInstances()
    @supermodel.trackRequest @courseInstances.fetchForClassroom(classroomID)

    @levels = new Levels()
    # @levels.fetchForClassroom(classroomID, {data: {project: 'name,original,practice,slug'}})
    # @levels.on 'add', (model) -> @_byId[model.get('original')] = model # so you can 'get' them
    @supermodel.trackRequest(@levels.fetchForClassroom(classroomID, {data: {project: 'name,original'}}))
    #
    # @user = new User({_id: studentID})
    # @supermodel.trackRequest(@user.fetch())

    @urls = require('core/urls')


    @singleStudentLevelProgressDotTemplate = require 'templates/teachers/hovers/progress-dot-single-student-level'
    @levelProgressMap = {}

    super(options)

  onLoaded: ->
    if @students.loaded and not @destroyed
      @user = _.find(@students.models, (s)=> s.id is @studentID)
      @updateLastPlayedString()
      @updateLevelProgressMap()
      @updateLevelDataMap()
      @render()
    super()

  afterRender: ->
    super(arguments...)
    $('.progress-dot, .btn-view-project-level').each (i, el) ->
      dot = $(el)
      dot.tooltip({
        html: true
        container: dot
      }).delegate '.tooltip', 'mousemove', ->
        dot.tooltip('hide')

    # @drawLineGraph()
    @drawBarGraph()
    @onChangeCourseChart()


  onChangeCourseChart: (e)->
    # show() the one that's selected
    # console.log ((e.currentTarget).value)
    if (e)
      selected = ('#visualisation-'+((e.currentTarget).value))
      $("[id|='visualisation']").hide()
      $(selected).show()


    # hide() all the others

  drawBarGraph: ->
    return unless @courses.loaded and @levels.loaded and @sessions?.loaded and @levelData

    WIDTH = 1142
    HEIGHT = 600
    MARGINS = {
      top: 50
      right: 20
      bottom: 50
      left: 50
    }

    # console.log (@classroom)

    for versionedCourse in @classroom.get('courses') ? []
      # this does all of the courses, logic for whether student was assigned is in corresponding jade file
      vis = d3.select('#visualisation-'+versionedCourse._id)
      courseLevelData = []
      for level in @levelData when level.courseID is versionedCourse._id
        courseLevelData.push level
        #TODO exclude practice levels from this graph.

      # console.log (courseLevelData)

      course = _.find @courses.models, (c) => c.id is versionedCourse._id

      levels = @classroom.getLevels({courseID: course.id}).models
      # console.log (levels)



      xRange = d3.scale.ordinal().rangeRoundBands([MARGINS.left, WIDTH - MARGINS.right], 0.1).domain(courseLevelData.map( (d) -> d.levelIndex))
      yRange = d3.scale.linear().range([HEIGHT - (MARGINS.top), MARGINS.bottom]).domain([0, d3.max(courseLevelData, (d) -> d.class)])
      xAxis = d3.svg.axis().scale(xRange).tickSize(2).tickSubdivide(true)
      yAxis = d3.svg.axis().scale(yRange).tickSize(2).orient('left').tickSubdivide(true)

      vis.append('svg:g').attr('class', 'x axis').attr('transform', 'translate(0,' + (HEIGHT - (MARGINS.bottom)) + ')').call xAxis
      vis.append('svg:g').attr('class', 'y axis').attr('transform', 'translate(' + MARGINS.left + ',0)').call yAxis

      chart = vis.selectAll('rect')
      .data(courseLevelData)
      .enter()
      chart.append('rect')
        .attr('id', 'classroom')
        .attr('x', ((d) -> xRange(d.levelIndex) + (xRange.rangeBand())/2))
        .attr('y', (d) -> yRange d.class)
        .attr('width', (xRange.rangeBand())/2)
        .attr('height', (d) -> HEIGHT - (MARGINS.bottom) - yRange(d.class))
        .attr('fill', '#5CB4D0')

      chart.append('text')
        .attr('x', ((d) -> xRange(d.levelIndex) + (xRange.rangeBand())/2))
        .attr('y', ((d) -> yRange(d.class) - 3 ))
        .text((d)-> if d.class isnt 0 then d.class)
        .attr('class', 'label')

      chart.append('rect')
        .attr('id', 'student')
        .attr('x', ((d) -> xRange d.levelIndex))
        .attr('y', (d) -> yRange d.student)
        .attr('width', (xRange.rangeBand())/2)
        .attr('height', (d) -> HEIGHT - (MARGINS.bottom) - yRange(d.student))
        .attr('fill', '#20572B')

      chart.append('text')
        .attr('x', ((d) -> xRange(d.levelIndex)) )
        .attr('y', ((d) -> yRange(d.student) - 3 ))
        .text((d)-> if d.student isnt 0 then d.student)
        .attr('class', 'label')
      #
      # vis.append("text")
      #   .attr("x", (WIDTH / 2))
      #   .attr("y", 20)
      #   .attr("text-anchor", "middle")
      #   .style("font-size", "16px")
      #   .text(course.get('name'))


      legend = vis.append("g")
        .attr("class", "legend")
        .attr("x", WIDTH - 20)
        .attr("width", 100)
        .attr("height", 100)

      legend.append("rect")
        .attr("x", WIDTH - 18)
        .attr("width", 18)
        .attr("height", 18)
        .style("fill", "#20572B")

      legend.append("text")
        .attr("x", WIDTH - 24)
        .attr("y", 9)
        .attr("dy", ".35em")
        .style("text-anchor", "end")
        .text("Student Playtime")

      legend.append("rect")
        .attr("x", WIDTH - 18)
        .attr("y", 25)
        .attr("width", 18)
        .attr("height", 18)
        .style("fill", "#5CB4D0")

      legend.append("text")
        .attr("x", WIDTH - 24)
        .attr("y", 30)
        .attr("dy", ".55em")
        .style("text-anchor", "end")
        .text("Class Average")

      labels = vis.append("g")

      labels.append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 60)
        .attr("x", -20)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text("Playtime in Seconds")

      labels.append("text")
        .attr("x", WIDTH/2)
        .attr("y", HEIGHT - 10)
        .text("Levels in " + (course.get('name')))
        .style("text-anchor", "middle")


  drawLineGraph: ->
    return unless @courses.loaded and @levels.loaded and @sessions?.loaded

    vis = d3.select('#visualisation')
    WIDTH = 1000
    HEIGHT = 500
    MARGINS = {
      top: 50
      right: 20
      bottom: 50
      left: 50
    }


    xScale = d3.scale.linear().range([MARGINS.left, WIDTH - MARGINS.right]).domain([
      d3.min(@levelData, (d) ->
        return d.levelIndex
      ),
      d3.max(@levelData, (d) ->
        return d.levelIndex
      )])

    yScale = d3.scale.linear().range([HEIGHT - MARGINS.top, MARGINS.bottom]).domain([
      d3.min(@levelData, (d) ->
        return d.student
      ),
      d3.max(@levelData, (d) ->
        return d.student
      )])

    xAxis = d3.svg.axis().scale(xScale)

    vis.append("svg:g")
    .attr("class","axis")
    .attr("transform", "translate(0," + (HEIGHT - MARGINS.bottom) + ")")
    .call(xAxis)

    yAxis = d3.svg.axis()
    .scale(yScale)
    .orient("left")

    vis.append("svg:g")
    .attr("class","axis")
    .attr("transform", "translate(" + (MARGINS.left) + ",0)")
    .call(yAxis)

    lineGenStudent = d3.svg.line()
      .x( (d)->
        return xScale(d.levelIndex)
      )
      .y( (d)->
        return yScale(d.student)
      )
      # .interpolate("basis")

    lineGenClass = d3.svg.line()
      .x( (d)->
        return xScale(d.levelIndex)
      )
      .y( (d)->
        return yScale(d.class)
      )

    # vis.append('svg:path')
    #   .attr('d', lineGenStudent(@levelData))
    #   .attr('stroke', 'green')
    #   .attr('stroke-width', 2)
    #   .attr('fill', 'none')

    # vis.append('svg:path')
    #   .attr('d', lineGenClass(@levelData))
    #   .attr('stroke', 'blue')
    #   .attr('stroke-width', 2)
    #   .attr('fill', 'none')


    dataGroup = d3.nest()
    .key( (d)->
      return d.courseID
    )
    .entries(@levelData)

    lSpace = WIDTH/dataGroup.length

    dataGroup.forEach (d, i) ->
      # console.log (d.values[0].courseName)



    dataGroup.forEach (d, i) ->
      console.log (lineGenStudent(d.values))
      vis.append('svg:path').attr('d', lineGenStudent(d.values)).attr('stroke', 'blue').attr('stroke-width', 2).attr('id', 'line_' + d.key).attr 'fill', 'none'
      # vis.append('svg:path').attr('d', lineGenClass(d.values)).attr('stroke', 'red').attr('stroke-width', 2).attr('id', 'line_' + d.key).attr 'fill', 'none'
      vis.append('text').attr('x', lSpace / 2 + i * lSpace).attr('y', HEIGHT).style('fill', 'black').attr('class', 'legend').on('click', ->
        active = if d.active then false else true
        opacity = if active then 0 else 1
        d3.select('#line_' + d.key).style 'opacity', opacity
        d.active = active
        return
      ).text d.values[0].courseName
      # console.log (d.values[0].courseName)
      return


    # console.log (@levelData)


  onClassroomSync: ->
    # Now that we have the classroom from db, can request all level sessions for this classroom
    @sessions = new LevelSessions()
    @sessions.comparator = 'changed' # Sort level sessions by changed field, ascending
    @listenTo @sessions, 'sync', @onSessionsSync
    @supermodel.trackRequests(@sessions.fetchForAllClassroomMembers(@classroom))

    @students = new Users()
    jqxhrs = @students.fetchForClassroom(@classroom, removeDeleted: true)
    # @listenTo @students, ->
    #   console.log @students
    @supermodel.trackRequests jqxhrs

  onSessionsSync: ->
    # Now we have some level sessions, and enough data to calculate last played string
    # This may be called multiple times due to paged server API calls via fetchForAllClassroomMembers
    return if @destroyed # Don't do anything if page was destroyed after db request
    @updateLastPlayedString()
    @updateLevelProgressMap()
    @updateLevelDataMap()


  # onCourseInstancesSync: ->
  #   # @sessions = new CocoCollection([], { model: LevelSession })
  #   for courseInstance in @courseInstances.models
  #     sessions = new CocoCollection([], { url: "/db/course_instance/#{courseInstance.id}/level_sessions", model: LevelSession })
  #     @supermodel.loadCollection(sessions, { data: { project: ['level', 'playtime', 'creator', 'changed', 'state.complete'].join(' ') } })
  #     courseInstance.sessions = sessions
  #     sessions.courseInstance = courseInstance
  #     courseInstance.sessionsByUser = {}
  #     @listenToOnce sessions, 'sync', (sessions) ->
  #       @sessions.add(sessions.slice())
  #       for courseInstance in @courseInstances.models
  #         courseInstance.sessionsByUser = courseInstance.sessions.groupBy('creator')
  #
  #   # Generate course instance JIT, in the meantime have models w/out equivalents in the db
  #   for course in @courses.models
  #     query = {courseID: course.id, classroomID: @classroom.id}
  #     courseInstance = @courseInstances.findWhere(query)
  #     if not courseInstance
  #       courseInstance = new CourseInstance(query)
  #       @courseInstances.add(courseInstance)
  #       courseInstance.sessions = new CocoCollection([], {model: LevelSession})
  #       # sessions.courseInstance = courseInstance
  #       courseInstance.sessionsByUser = {}

  updateLastPlayedString: ->
    # Make sure all our data is loaded, @sessions may not even be intialized yet
    return unless @courses.loaded and @levels.loaded and @sessions?.loaded and @user?.loaded

    # Use lodash to find the last session for our user, @sessions already sorted by changed date
    session = _.findLast @sessions.models, (s) => s.get('creator') is @user.id

    return unless session

    # Find course for this level session, for it's name
    # Level.original is the original id, used for level versioning, and connects levels to level sessions
    for versionedCourse in @classroom.get('courses') ? []
      for level in versionedCourse.levels
        if level.original is session.get('level').original
          # Found the level for our level session in the classroom versioned courses
          # Find the full course so we can get it's name
          course = _.find @courses.models, (c) => c.id is versionedCourse._id
          break

    # Find level for this level session, for it's name
    level = @levels.findWhere({original: session.get('level').original})

    # Update last played string based on what we found
    @lastPlayedString = ""
    @lastPlayedString += course.get('name') if course
    @lastPlayedString += ", " if course and level
    @lastPlayedString += level.get('name') if level
    @lastPlayedString += ", " if @lastPlayedString
    @lastPlayedString += session.get('changed')
    # Rerun template/jade file to display new last played string
    @render()

  updateLevelProgressMap: ->
    return unless @courses.loaded and @levels.loaded and @sessions?.loaded and @user?.loaded

    # Map levels to sessions once, so we don't have to search entire session list multiple times below
    @levelSessionMap = {}
    for session in @sessions.models when session.get('creator') is @studentID
      @levelSessionMap[session.get('level').original] = session


    # Create mapping of level to student progress
    @levelProgressMap = {}
    for versionedCourse in @classroom.get('courses') ? []
      for versionedLevel in versionedCourse.levels
        session = @levelSessionMap[versionedLevel.original]
        if session
          if session.get('state')?.complete
            @levelProgressMap[versionedLevel.original] = 'complete'
          else
            @levelProgressMap[versionedLevel.original] = 'started'
        else
          @levelProgressMap[versionedLevel.original] = 'not started'

  updateLevelDataMap: ->
    return unless @courses.loaded and @levels.loaded and @sessions?.loaded

    @levelData = []
    for versionedCourse in @classroom.get('courses') ? []
      course = _.find @courses.models, (c) => c.id is versionedCourse._id
      for versionedLevel in versionedCourse.levels
        @playTime = 0
        @timesPlayed = 0
        @studentTime = 0
        @levelProgress = 'not started'
        for session in @sessions.models
          if session.get('level').original == versionedLevel.original
            @playTime += session.get('playtime') or 0
            @timesPlayed += 1
            if session.get('creator') is @studentID
              @studentTime = session.get('playtime')
              if @levelProgressMap[versionedLevel.original] == 'complete'
                @levelProgress = 'complete'
              else if @levelProgressMap[versionedLevel.original] == 'started'
                @levelProgress = 'started'
        # if @timesPlayed
        classAvg = if @timesPlayed then Math.round(@playTime / @timesPlayed) else 0
        @levelData.push {
          levelID: versionedLevel.original
          levelIndex: @classroom.getLevelNumber(versionedLevel.original)
          levelName: versionedLevel.name
          courseName: course.get('name')
          courseID: course.get('_id')
          class: classAvg
          student: @studentTime
          levelProgress: @levelProgress
          # required:
        }
    # console.log (@levelData)

    # new map for averages of all classroom playtimes
    # @averageLevelPlaytimeMap = {}
    #   for versionedCourse in @classroom.get('courses') ? []
    #     for versionedLevel in versionedCourse.levels
    #       var totalPlaytime = null
    #       var totalSessions = 0
    #       session = @levelSessionMap[versionedLevel.original]
    #       # get playtimes for each session in all classroom sessions of this course with this particular level
    #       if totalPlaytime
    #         var averagePlaytime = totalPlaytime / totalSessions
    #         @averagePlaytimeMap[versionedLevel.original] = averagePlaytime

  studentStatusString: () ->
    status = @user.prepaidStatus()
    expires = @user.get('coursePrepaid')?.endDate
    string = switch status
      when 'not-enrolled' then $.i18n.t('teacher.status_not_enrolled')
      when 'enrolled' then (if expires then $.i18n.t('teacher.status_enrolled') else '-')
      when 'expired' then $.i18n.t('teacher.status_expired')
    return string.replace('{{date}}', moment(expires).utc().format('l'))

  onClickEnrollStudentButton: (e) ->
    userID = $(e.currentTarget).data('user-id')
    user = @user.get(userID)
    selectedUsers = new Users([user])
    @enrollStudents(selectedUsers)
    window.tracker?.trackEvent $(e.currentTarget).data('event-action'), category: 'Teachers', classroomID: @classroom.id, userID: userID, ['Mixpanel']

  enrollStudents: (selectedUsers) ->
    modal = new ActivateLicensesModal { @classroom, selectedUsers, users: @user }
    @openModalView(modal)
    modal.once 'redeem-users', (enrolledUsers) =>
      enrolledUsers.each (newUser) =>
        user = @user.get(newUser.id)
        if user
          user.set(newUser.attributes)
      null



  # onLoaded: ->
  #   console.log("on loaded")
  #   for courseInstance in @courseInstances.models
  #     courseID = courseInstance.get('courseID')
  #     course = @courses.get(courseID)
  #     # courseInstance.sessions.course = course
  #   @updateLastPlayedString()
  #   super()
  #
  # afterRender: ->
  #   @$('[data-toggle="popover"]').popover({
  #     html: true
  #     trigger: 'hover'
  #     placement: 'top'
  #   })
  #   super()
  #
  # levelPopoverContent: (level, session, i) ->
  #   return null unless level
  #   context = {
  #     moment: moment
  #     level: level
  #     session: session
  #     i: i
  #     canViewSolution: @teacherMode
  #   }
  #   return popoverTemplate(context)
  #
  # getLevelURL: (level, course, courseInstance, session) ->
  #   return null unless @teacherMode and _.all(arguments)
  #   "/play/level/#{level.get('slug')}?course=#{course.id}&course-instance=#{courseInstance.id}&session=#{session.id}&observing=true"

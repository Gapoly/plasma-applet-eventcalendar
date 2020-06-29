import QtQuick 2.0
import org.kde.plasma.plasmoid 2.0
import "../code/WeatherApi.js" as WeatherApi

Item {
	readonly property Item popup: root.Plasmoid.fullRepresentationItem

	//--- Weather
	property var dailyWeatherData: { "list": [] }
	property var hourlyWeatherData: { "list": [] }
	property var currentWeatherData: null
	property var lastForecastAt: null
	property var lastForecastErr: null


	//--- Main
	Component.onCompleted: {
		console.log('logic onCompleted')
		console.log('timeModel', timeModel)
		console.log('eventModel', eventModel)
		console.log('agendaModel', agendaModel)

		pollTimer.start()
	}


	//--- Update
	Timer {
		id: pollTimer
		
		repeat: true
		triggeredOnStart: true
		interval: plasmoid.configuration.events_pollinterval * 60000
		onTriggered: logic.update()
	}

	function update() {
		logger.debug('update')
		logic.updateData()
	}

	function updateData() {
		logger.debug('updateData')
		logic.updateEvents()
		logic.updateWeather()
	}



	//--- Events
	function updateEvents() {
		updateEventsTimer.restart()
	}
	Timer {
		id: updateEventsTimer
		interval: 200
		onTriggered: logic.deferredUpdateEvents()
	}
	function deferredUpdateEvents() {
		var range = agendaModel.getDateRange(agendaModel.currentMonth)
		// console.log('   first', monthView.firstDisplayedDate())
		// console.log('    last', monthView.lastDisplayedDate())

		agendaModel.visibleDateMin = range.min
		agendaModel.visibleDateMax = range.max
		eventModel.fetchAll(range.min, range.max)
	}


	//--- Weather
	function updateWeather(force) {
		if (WeatherApi.weatherIsSetup()) {
			// update every hour
			var shouldUpdate = false
			if (lastForecastAt) {
				var now = new Date()
				var currentHour = now.getHours()
				var lastUpdateHour = new Date(lastForecastAt).getHours()
				var beenOverAnHour = now.valueOf() - lastForecastAt >= 60 * 60 * 1000
				if (lastUpdateHour != currentHour || beenOverAnHour) {
					shouldUpdate = true
				}
			} else {
				shouldUpdate = true
			}
			
			if (force || shouldUpdate) {
				updateWeatherTimer.restart()
			}
		}
	}
	Timer {
		id: updateWeatherTimer
		interval: 100
		onTriggered: logic.deferredUpdateWeather()
	}
	function deferredUpdateWeather() {
		logic.updateDailyWeather()

		if (popup.showMeteogram) {
			logic.updateHourlyWeather()
		}
	}

	function handleWeatherError(funcName, err, data, xhr) {
		logger.log(funcName + '.err', err, xhr && xhr.status, data)
		lastForecastAt = Date.now() // If there's an error, don't bother the API for another hour.
		if (xhr && xhr.status == 429) {
			logic.lastForecastErr = i18n("Weather API limit reached, will try again soon.")
		} else {
			logic.lastForecastErr = err
		}
	}

	function updateDailyWeather() {
		logger.debug('updateDailyWeather', lastForecastAt, Date.now())
		WeatherApi.updateDailyWeather(function(err, data, xhr) {
			if (err) return handleWeatherError('updateDailyWeather', err, data, xhr)
			logger.debugJSON('updateDailyWeather.response', data)

			logic.lastForecastAt = Date.now()
			logic.lastForecastErr = null
			logic.dailyWeatherData = data
			popup.updateUI()
		})
	}

	function updateHourlyWeather() {
		logger.debug('updateHourlyWeather', lastForecastAt, Date.now())
		WeatherApi.updateHourlyWeather(function(err, data, xhr) {
			if (err) return handleWeatherError('updateHourlyWeather', err, data, xhr)
			logger.debugJSON('updateHourlyWeather.response', data)

			logic.lastForecastAt = Date.now()
			logic.lastForecastErr = null
			logic.hourlyWeatherData = data
			logic.currentWeatherData = data.list[0]
			popup.updateMeteogram()
		})
	}

	//---
	Connections {
		target: plasmoid.configuration
		onWeather_serviceChanged: {
			logic.dailyWeatherData = { "list": [] }
			logic.hourlyWeatherData = { "list": [] }
			logic.currentWeatherData = null
			popup.updateUI()
		}
	}
}
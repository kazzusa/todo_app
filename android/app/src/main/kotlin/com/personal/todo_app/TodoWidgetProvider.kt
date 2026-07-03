package com.personal.todo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

class TodoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> updateWidget(context, manager, id) }
    }

    companion object {
        private val ROW_IDS = intArrayOf(
            R.id.widget_task_0, R.id.widget_task_1, R.id.widget_task_2, R.id.widget_task_3,
            R.id.widget_task_4, R.id.widget_task_5, R.id.widget_task_6, R.id.widget_task_7
        )

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodoWidgetProvider::class.java))
            ids.forEach { id -> updateWidget(context, manager, id) }
        }

        private fun loadTasks(context: Context): List<String> {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val json = prefs.getString("flutter.widget_tasks", "[]") ?: "[]"
                val arr = JSONArray(json)
                (0 until minOf(arr.length(), ROW_IDS.size)).map { i ->
                    val obj = arr.getJSONObject(i)
                    val title = obj.optString("title", "")
                    val cat = if (obj.has("category") && !obj.isNull("category"))
                        " · ${obj.getString("category").replaceFirstChar { c -> c.uppercase() }}" else ""
                    "· $title$cat"
                }
            } catch (e: Exception) {
                emptyList()
            }
        }

        private fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.todo_widget)
            val tasks = loadTasks(context)

            // "+" button → open app with ADD_TASK
            val addIntent = Intent(context, MainActivity::class.java).apply {
                action = "ADD_TASK"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_button,
                PendingIntent.getActivity(context, 1, addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            // Fill task rows
            ROW_IDS.forEachIndexed { i, viewId ->
                if (i < tasks.size) {
                    views.setTextViewText(viewId, tasks[i])
                    views.setViewVisibility(viewId, View.VISIBLE)
                    // Tap row → open app
                    views.setOnClickPendingIntent(
                        viewId,
                        PendingIntent.getActivity(context, 10 + i,
                            Intent(context, MainActivity::class.java),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    )
                } else {
                    views.setViewVisibility(viewId, View.GONE)
                }
            }

            views.setViewVisibility(
                R.id.widget_empty_text,
                if (tasks.isEmpty()) View.VISIBLE else View.GONE
            )

            manager.updateAppWidget(id, views)
        }
    }
}

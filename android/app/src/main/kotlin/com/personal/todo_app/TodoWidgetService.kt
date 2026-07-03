package com.personal.todo_app

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TodoWidgetFactory(applicationContext)
}

class TodoWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private data class TaskItem(val title: String, val category: String?)

    private var items: List<TaskItem> = emptyList()

    override fun onCreate() = load()
    override fun onDataSetChanged() = load()
    override fun onDestroy() {}
    override fun getCount() = items.size
    override fun getViewTypeCount() = 1
    override fun hasStableIds() = true
    override fun getItemId(pos: Int) = pos.toLong()
    override fun getLoadingView(): RemoteViews? = null

    private fun load() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.widget_tasks", "[]") ?: "[]"
        val arr = try { JSONArray(json) } catch (_: Exception) { JSONArray() }
        items = (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            TaskItem(
                title = obj.optString("title", ""),
                category = if (obj.has("category") && !obj.isNull("category"))
                    obj.getString("category") else null
            )
        }
    }

    override fun getViewAt(pos: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.todo_widget_item)
        val item = items.getOrNull(pos) ?: return views

        views.setTextViewText(R.id.widget_task_title, item.title)

        if (item.category != null) {
            val label = item.category.replaceFirstChar { it.uppercase() }
            views.setTextViewText(R.id.widget_task_category, label)
            views.setViewVisibility(R.id.widget_task_category, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_task_category, View.GONE)
        }

        // Needed for setPendingIntentTemplate to work
        views.setOnClickFillInIntent(R.id.widget_item_root, Intent())
        return views
    }
}

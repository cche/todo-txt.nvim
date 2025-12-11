local storage = require("todo-txt.storage")
local parser = require("todo-txt.parser")

local M = {}

local function parse_tracked_time(tracked_str)
  if not tracked_str then
    return 0
  end

  local hours, minutes, seconds = tracked_str:match("tracked:(%d+)h(%d+)m(%d+)s")
  if not hours then
    return 0
  end

  return tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)
end

local function format_time_seconds(total_seconds)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor((total_seconds % 3600) / 60)
  local seconds = total_seconds % 60

  return string.format("%dh%dm%ds", hours, minutes, seconds)
end

function M.aggregate_time_by_tags(config)
  local project_times = {}
  local context_times = {}
  local total_time = 0

  local files_to_process = { config.todo_file }
  if config.done_file then
    table.insert(files_to_process, config.done_file)
  end

  for _, file_path in ipairs(files_to_process) do
    local entries = storage.get_entries(file_path)

    for _, entry in ipairs(entries) do
      local task = parser.parse(entry)
      local tracked_time = task.tracked_time

      if tracked_time then
        local time_seconds = parse_tracked_time(tracked_time)
        total_time = total_time + time_seconds

        for project, _ in pairs(task.projects) do
          project_times[project] = (project_times[project] or 0) + time_seconds
        end

        for context, _ in pairs(task.contexts) do
          context_times[context] = (context_times[context] or 0) + time_seconds
        end
      end
    end
  end

  return {
    projects = project_times,
    contexts = context_times,
    total = total_time,
  }
end

function M.format_summary(summary)
  local lines = {}

  table.insert(lines, "Time Tracking Summary")
  table.insert(lines, "=====================")
  table.insert(lines, "")

  if next(summary.projects) then
    table.insert(lines, "By Project:")
    table.insert(lines, "-----------")

    local sorted_projects = {}
    for project, time in pairs(summary.projects) do
      table.insert(sorted_projects, { name = project, time = time })
    end
    table.sort(sorted_projects, function(a, b)
      return a.time > b.time
    end)

    for _, item in ipairs(sorted_projects) do
      table.insert(lines, string.format("  +%-20s %s", item.name, format_time_seconds(item.time)))
    end
    table.insert(lines, "")
  end

  if next(summary.contexts) then
    table.insert(lines, "By Context:")
    table.insert(lines, "-----------")

    local sorted_contexts = {}
    for context, time in pairs(summary.contexts) do
      table.insert(sorted_contexts, { name = context, time = time })
    end
    table.sort(sorted_contexts, function(a, b)
      return a.time > b.time
    end)

    for _, item in ipairs(sorted_contexts) do
      table.insert(lines, string.format("  @%-20s %s", item.name, format_time_seconds(item.time)))
    end
    table.insert(lines, "")
  end

  table.insert(lines, "Total Time:")
  table.insert(lines, "-----------")
  table.insert(lines, string.format("  %s", format_time_seconds(summary.total)))

  return lines
end

return M

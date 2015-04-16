#!/usr/bin/ruby

require 'harvested'
require 'pry'
require 'json'
require 'pp'
require 'time'

class TimeTracker
  attr_reader :harvest
  attr_reader :tasks

  WORKHOURS_PER_DAY = 8.0

  def initialize
    configure_harvested
  end

  def print_project_info(project_id, time_budget = nil)
    project = @harvest.projects.find project_id
    task_assignments = get_project_task_assignments project_id

    puts "*"*20
    puts "1. Project Info:"
    puts "-"*10
    pp JSON.parse(project.as_json.to_json)
    puts "*"*20

    puts "2. Project tasks:"
    puts "-"*10
    print_project_tasks project_id
    puts "*"*20

    puts "3. Project members:"
    puts "-"*10
    print_project_members project_id
    puts "*"*20

    puts "Analyzing project..."
    ana_result = analyse_project project, task_assignments

    puts "4. Total Billable hours:"
    puts "-"*10
    puts ana_result[:total_billable_hours]
    total_billable_workdays = ana_result[:total_billable_hours]/WORKHOURS_PER_DAY
    puts "#{total_billable_workdays} days"
    puts ""

    puts "5. Total Unbillable hours:"
    puts "-"*10
    puts ana_result[:total_unbillable_hours]
    puts "#{ana_result[:total_unbillable_hours]/WORKHOURS_PER_DAY} days"
    puts ""

    puts "6. Total hours:"
    puts "-"*10
    puts ana_result[:total_hours]
    puts "#{ana_result[:total_hours]/WORKHOURS_PER_DAY} days"
    puts ""

    unless time_budget.nil?
      left = time_budget - total_billable_workdays
      puts "7. Billable Time Budget left in days:"
      puts "-"*10
      pp "#{left} billable days left"
      puts ""
    end
  end

  def print_project_tasks(project_id)
    tasks = get_project_task_assignments project_id
    tasks.each do |t|
      puts "  - #{get_task_summary(t.task_id)}"
    end
  end

  def print_project_members(project_id)
    members = @harvest.user_assignments.all project_id
    members.each do |m|
      user = @harvest.users.find m.user_id
      puts  "  - #{user.email}"
    end
  end

  private

  def configure_harvested
    raise "No HARVEST_ACCOUNT_HOST env setting defined!" if ENV['HARVEST_ACCOUNT_HOST'].nil?
    raise "No HARVEST_USERNAME env setting defined!" if ENV['HARVEST_USERNAME'].nil?
    raise "No HARVEST_TOKEN env setting defined!" if ENV['HARVEST_TOKEN'].nil?

    account_host = ENV['HARVEST_ACCOUNT_HOST']
    username = ENV['HARVEST_USERNAME']
    token = ENV['HARVEST_TOKEN']

    @harvest = ::Harvest.hardy_client(account_host, username, token)
  end

  def get_project_times(project, start_date, end_date)
    @harvest.reports.time_by_project project, start_date, end_date
  end

  def get_project_task_assignments(project_id)
    @harvest.task_assignments.all(project_id)
  end

  def get_task_summary(task_id)
    @tasks = Hash.new if @tasks.nil?

    task = @tasks[task_id].nil? ? @harvest.tasks.find(task_id) : task = @tasks[task_id]

    @tasks[task_id] = task
    billable = "Unbillable"
    billable = "Billable" if task.billable_by_default
    str = "#{task.name} -> #{billable}"
  end

  def analyse_project(project, task_assignments)
    project_start_date = DateTime.parse(project.starts_on)
    today = Time.now
    project_times = get_project_times project, project_start_date, today


    total_hours = 0.0
    total_billable_hours = 0.0
    total_unbillable_hours = 0.0

    project_times.each do |pt|
      hours = pt.hours
      total_hours += hours

      if is_billable? pt.task_id
        total_billable_hours += hours
      else
        total_unbillable_hours += hours
      end
    end

    {
      total_hours: total_hours,
      total_billable_hours: total_billable_hours,
      total_unbillable_hours: total_unbillable_hours
    }
  end

  def is_billable?(task_id)
    get_task_summary task_id
    @tasks[task_id].billable_by_default == true
  end

  def is_unbillable?(task_id)
    !is_billable?
  end
end

def read_args
  puts "Arguments: "
  pp ARGV.inspect

  {
    project_id: ARGV[0].to_i,
    time_budget: ARGV[1].to_i
  }
end

tt = TimeTracker.new
project_id = read_args[:project_id]
tt.print_project_info project_id, read_args[:time_budget]

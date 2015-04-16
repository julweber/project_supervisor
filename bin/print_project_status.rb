#!/usr/bin/ruby

# This is hacked down dirty as is. Live with it .... :)

require 'harvested'
require 'pry'
require 'json'
require 'pp'
require 'time'

DEFAULT_AVERAGE_HOUR_COST = 60.0

class TimeTracker
  attr_reader :harvest
  attr_reader :tasks

  WORKHOURS_PER_DAY = 8.0

  def initialize
    configure_harvested
  end

  def print_project_info(project_id, time_budget = nil, average_hour_cost = DEFAULT_AVERAGE_HOUR_COST)
    project = @harvest.projects.find project_id
    task_assignments = get_project_task_assignments project_id

    puts "*"*20
    puts "1. Project Info:"
    puts "-"*10
    pp JSON.parse(project.as_json.to_json)
    puts "*"*20

    puts "2. Project tasks:"
    puts "-"*10
    print_project_tasks project
    puts "*"*20

    puts "3. Project members:"
    puts "-"*10
    print_project_members project
    puts "*"*20

    puts "Analyzing project..."
    ana_result = analyse_project project, task_assignments

    puts "4. Total Billable hours:"
    puts "-"*10
    puts "  #{ana_result[:total_billable_hours].round(2)} h"
    total_billable_workdays = (ana_result[:total_billable_hours]/WORKHOURS_PER_DAY).round(2)
    puts "  #{total_billable_workdays} days"
    percentage = ((ana_result[:total_billable_hours] / ana_result[:total_hours]) * 100).round(2)
    puts "  Percentage: #{percentage} %"
    puts ""

    puts "5. Total Unbillable hours:"
    puts "-"*10
    puts "  #{ana_result[:total_unbillable_hours].round(2)} h"
    puts "  #{(ana_result[:total_unbillable_hours]/WORKHOURS_PER_DAY).round(2)} days"
    percentage = ((ana_result[:total_unbillable_hours] / ana_result[:total_hours]) * 100).round(2)
    puts "  Percentage: #{percentage} %"
    puts ""

    puts "6. Total hours:"
    puts "-"*10
    puts "  #{ana_result[:total_hours].round(2)} h"
    puts "  #{(ana_result[:total_hours]/WORKHOURS_PER_DAY).round(2)} days"
    puts ""

    unless time_budget.nil? || time_budget == 0
      left = (time_budget - total_billable_workdays).round(2)
      puts "7. Billable Time Budget left in days:"
      puts "-"*10
      puts "  #{left} billable days left"
      puts ""
    end

    puts "8. Generated Cash flow:"
    puts "-"*10
    cash = ana_result[:total_billable_hours] * project.hourly_rate
    puts "  #{cash.round(2)} €"
    puts ""

    puts "9. Internal cost based on #{average_hour_cost} € / hour:"
    puts "-"*10
    cost = calculate_average_cost(average_hour_cost, ana_result[:total_hours]).round(2)
    puts "  #{cost.round(2)} €"
    puts ""

    puts "10. Cash flow result:"
    puts "-"*10
    res_cash = cash - cost
    puts "  #{res_cash.round(2)} €"
    puts ""
  end

  private

  def print_project_tasks(project)
    tasks = get_project_task_assignments project.id
    tasks.each do |t|
      puts "  - #{get_task_summary(t.task_id)}"
    end
  end

  def print_project_members(project)
    members = @harvest.user_assignments.all project.id
    @members = members
    puts "Employee hours: "
    members.each do |m|
      user = @harvest.users.find m.user_id
      res = get_project_times_per_user m.user_id, project
      puts  "  - #{user.email} -> Billable: #{res[:total_billable_hours].round(2)}h, Unbillable: #{res[:total_unbillable_hours].round(2)}h, Total: #{res[:total_hours].round(2)}h, BP: #{res[:billable_percentage]} %"
    end
  end

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

  def get_project_times_per_user(user_id, project)
    project_start_date = DateTime.parse(project.starts_on)
    today = Time.now

    time_by_user = @harvest.reports.time_by_user(user_id, project_start_date, today, { project: project.id })

    res = analyze_times time_by_user
    res
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

    analyze_times project_times
  end

  def calculate_average_cost(average_hour_cost = DEFAULT_AVERAGE_HOUR_COST, hours)
    average_hour_cost * hours
  end

  def analyze_times(project_times)
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

    billable_percentage = 0.0
    begin
      billable_percentage = ((total_billable_hours/total_hours) * 100).round(2)
    rescue
    end

    {
      total_hours: total_hours,
      total_billable_hours: total_billable_hours,
      total_unbillable_hours: total_unbillable_hours,
      billable_percentage: billable_percentage
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

  average_hour_cost = DEFAULT_AVERAGE_HOUR_COST

  average_hour_cost = ARGV[2].to_i unless ARGV[2].nil?

  {
    project_id: ARGV[0].to_i,
    time_budget: ARGV[1].to_i,
    average_hour_cost: average_hour_cost
  }
end

tt = TimeTracker.new
project_id = read_args[:project_id]
args = read_args
tt.print_project_info project_id, args[:time_budget], args[:average_hour_cost]

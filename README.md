# Project supervisor

Helpful scripts concerning project management and monitoring using the harvest API.

## Usage

### Configure Environment

Adjust the script in bin/set_harvest_env.sh to fit your credentials information:

    cp bin/set_harvest_env.sh.example bin/set_harvest_env.sh
    source bin/set_harvest_env.sh

### print_project_status.rb

Prints project information for the given project

#### General

    bundle exec ruby bin/print_project_status.rb <project_id> <time_budget_in_days(optional)>

#### Example

    bundle exec ruby bin/print_project_status.rb 7723495 120

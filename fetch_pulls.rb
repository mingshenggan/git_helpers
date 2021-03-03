#/bin/ruby

require "octokit"
require "pry"
require "active_support"
require "pp"

# Configure reviews accordingly
Octokit.configure do |c|
  c.api_endpoint = ENV["ENTERPRISE_URL"] || "https://api.github.com"
end
# Need to assign env var ENTERPRISE_GITHUB_TOKEN
@client = Octokit::Client.new(access_token: ENV["ENTERPRISE_GITHUB_TOKEN"])

# {
#   mingsheng: { approved: 0, reviewed: 0, total: 0 }
# }

def check_repo(name)
  # last month = cutoff for review to be considered
  today = Date.today
  cutoff = Date.new(today.year, today.prev_month.month, 1)
  total_reviews = {total: 0}

  puts "========="
  puts " #{name}"
  puts "========="

  # TODO: Pagination not supported yet...
  # Fetch all pull requests
  prs = @client.pull_requests(name, state: :all)

  # For each PR
  prs.each do |pr|
    # Skip PRs created before cutoff
    break if pr.created_at.to_date < cutoff
    total_reviews[:total] += 1

    prn = pr.number
    # Fetch all reviews and register each reviewer / approver
    reviews = @client.pull_request_reviews(name, pr.number).reduce({}) do |res, rv|
      # Skip reviews before cutoff
      next res if rv.submitted_at.to_date < cutoff
      res[rv.user.login] ||= { approved: 0, reviewed: 1 }
      if rv.state == "APPROVED"
        res[rv.user.login][:approved] = 1
      end
      res
    end

    reviews.each do |k,v|
      total_reviews[k] ||= { approved: 0, reviewed: 0 }
      total_reviews[k][:approved] += v[:approved]
      total_reviews[k][:reviewed] += v[:reviewed]
    end
  end

  pp total_reviews
end

# Run script for each starred repo
@client.starred.each do |starred|
  check_repo(starred.full_name)
end

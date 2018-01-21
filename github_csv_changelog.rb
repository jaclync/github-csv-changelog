require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'csv'
require 'io/console'
require 'optparse'

# /// Constants. ///

GITHUB_API_NOTE = "Github commit parser."
COMMIT_PARSER_API_TOKEN_ENV_KEY = "COMMIT_PARSER_API_TOKEN"

# /// Helper functions for network requests. ///

# Makes POST request with default SSL usage.
def post(url, username, password, body_JSON)
  uri = URI.parse(url)
  request = Net::HTTP::Post.new(uri)
  request.basic_auth username, password
  request.body = JSON.dump(body_JSON)
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  return response
end

# Makes GET request for Github API request.
def get(url, access_token)
  uri = URI.parse(url)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "token #{access_token}"

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  return response
end

# /// Network requests. ///

# Pings for 2-factor one-time password.
def request_2factor_passcode(username, password)
  url = 'https://api.github.com/authorizations'
  body_JSON = JSON.dump({
                          "scopes" => [
                            "repo",
                            "user"
                          ],
                          "note" => GITHUB_API_NOTE
                        })
  response = post(url, username, password, body_JSON)
  return !response['x-github-otp'].nil? && response.code === "401"
end

# Gets access token with one-time password for 2 factor authentication.
# This does not call `post` helper due to its special handling for one-time password (`otp`).
def get_token_with_2factor_otp(username, password, otp)
  uri = URI.parse("https://api.github.com/authorizations")
  body_JSON = JSON.dump({
                          "scopes" => [
                            "repo",
                            "user"
                          ],
                          "note" => GITHUB_API_NOTE
                        })

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  request = Net::HTTP::Post.new(uri)
  request["X-Github-Otp"] = otp
  request.basic_auth username, password
  request.body = body_JSON
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  body = parse_http_response(response)
  return body['token']
end

# Fetches commits between two branches.
def get_commits_between_two_branches(repo_owner, repo, branch_1, branch_2, access_token)
  url = "https://api.github.com/repos/#{repo_owner}/#{repo}/compare/#{branch_1}...#{branch_2}"
  response = get(url, access_token)
  body = parse_http_response(response)
  return body['commits']
end

# Fetches pull request and returns text content of pull request description.
def get_pull_request(pull_request_number, repo_owner, repo, access_token)
  url = "https://api.github.com/repos/#{repo_owner}/#{repo}/pulls/#{pull_request_number}"
  response = get(url, access_token)
  pull_request_body = parse_http_response(response)['body']
  return pull_request_body
end

# Extracts text from a Github pull request given regex.
def extract_text_from_pull_request_number(regex, pull_request_body)
  match_results = pull_request_body.scan(regex)
  if !match_results.nil? && match_results.length > 0
    text = match_results[0][0]
    puts text
    return text.gsub!(/^[\r\n]*/, '').gsub!(/[\r\n\-]*$/, '')
  else
    return ""
  end
end

# Exports commits with pull request information to CSV.
# pull_request_regex_by_field: optional hash from CSV field name to pull request description regex.
def export_commits_to_CSV(commits, repo_owner, repo, access_token, pull_request_regex_by_field, export_CSV_path)
  pull_request_fields = pull_request_regex_by_field.nil? ? [] : pull_request_regex_by_field.keys
  CSV.open(export_CSV_path, "wb") do |csv|
    fields = ["Author", "Date", "Commit message"] + pull_request_fields + ["Pull request url", "Commit url", "SHA"]
    csv << fields
    commits.each do |commit|
      author = commit['commit']['author']['name']
      date = commit['commit']['author']['date']
      commit_message = commit['commit']['message'].split("\n").first
      commit_url = commit['html_url']
      sha = commit['sha']

      values = [author, date, commit_message]

      # Extracts pull request number.
      match_results = commit_message.scan(/\(#([0-9]+)\)\n?$/)
      if !match_results.nil? && match_results.length > 0
        pull_request_number = match_results[0][0]
        pull_request_url = "https://github.com/#{repo_owner}/#{repo}/pull/#{pull_request_number}"

        pull_request_body = get_pull_request(pull_request_number, repo_owner, repo, access_token)
        puts pull_request_body

        pull_request_fields.each do |field|
          pull_request_regex = pull_request_regex_by_field[field]
          regex = Regexp.new(pull_request_regex, Regexp::MULTILINE)
          text = extract_text_from_pull_request_number(regex, pull_request_body)
          values = values + [text]
        end
        # Pull request url.
        values = values + [pull_request_url]
      else
        # No pull request can be deduced from commit message.
        pull_request_fields.each do |_|
          values = values + ['n/a']
        end
        # Pull request url.
        values = values + ['n/a']
      end
      values = values + [commit_url, sha]
      csv << values
    end
  end
end

# Parses http response as JSON and returns body field.
def parse_http_response(response)
  raise "Network error: #{response.code}" unless response.code == "200"
  body = JSON.parse(response.body)
  return body
end

# Prompts for user input.
def prompt(*args)
  print(*args)
  gets.chomp
end

# Prompts for user input on sensitive information (e.g. password, access token).
def prompt_sensitive_info(*args)
  print(*args)
  STDIN.noecho(&:gets).chomp
end

# Reads value from environment variable given key.
def get_token_from_environment_variable(key)
  return ENV[key]
end

# /// Beginning of script. ///
options = {}
OptionParser.new do |opt|
  opt.on('--api_token TOKEN') { |o| options[:access_token] = o }
  opt.on('--repo_owner REPO_OWNER') { |o| options[:repo_owner] = o }
  opt.on('--repo REPO') { |o| options[:repo] = o }
  opt.on('--export_CSV_path EXPORT_CSV_PATH') { |o| options[:export_CSV_path] = o }
  opt.on('--branch_1 BRANCH_1') { |o| options[:branch_1] = o }
  opt.on('--branch_2 BRANCH_2') { |o| options[:branch_2] = o }
  opt.on('--pull_request_regex_by_field PR_REGEX_BY_FIELD') { |o| options[:pull_request_regex_by_field] = o }
end.parse!

# Reads from command options.
access_token = options[:access_token]
repo_owner = options[:repo_owner]
repo = options[:repo]
export_CSV_path = options[:export_CSV_path]
branch_1 = options[:branch_1]
branch_2 = options[:branch_2]
if !options[:pull_request_regex_by_field].nil?
	pull_request_regex_by_field = JSON.parse(options[:pull_request_regex_by_field])
end

# If user did not provide access token via command options, try a few things in order:
# 1) try reading from environment variable if user chose to set it before.
# 2) user probably calls script for the first time. In this case, start asking for basic
#    auth (username, password), and requesting One-Time Password (OTP) for 2-factor auth.
#    After a GitHub API token is generated, prompt user to save token safely:
#    - save to 1Password and provide token via command options `--api_token=#{token}`
#    - provide instruction to save token to local environment variable to `COMMIT_PARSER_API_TOKEN_ENV_KEY`

# 1) Tries reading environment variable.
if access_token.nil? || access_token.empty?
  access_token = get_token_from_environment_variable(COMMIT_PARSER_API_TOKEN_ENV_KEY)
end

# 2) Starts requesting for API token.
if access_token.nil? || access_token.empty?
  username = prompt "Your GitHub username: "
  password = prompt_sensitive_info "Your GitHub password: "
  print "\n"
  otp_requested = request_2factor_passcode(username, password)
  if otp_requested
    one_time_passcode = prompt "Your GitHub One-Time Password: "
    access_token = get_token_with_2factor_otp(username, password, one_time_passcode)
    if !(access_token.nil? || access_token.empty?)
      puts "🔑 Token fetched! Your token is: #{access_token}"
    end
    if access_token.nil? || access_token.empty?
      puts "Please check for access token for entry with '#{GITHUB_API_NOTE}' at https://github.com/settings/tokens and regenerate access token if already exists."
      access_token = prompt_sensitive_info "Your personal token for GithubCommitParser: "
    end
    if !(access_token.nil? || access_token.empty?)
      puts "This is like a password and please save it safely like in 1Password for future access to Github API."
      puts "Next time running this, you can provide this token via --api_token option, or you can save it to your environment variable via command line by running:"
      puts "export COMMIT_PARSER_API_TOKEN=#{access_token}"
      puts "(If using zsh, add this export to the zshrc file.)"
    end
  end
end

if access_token.nil? || access_token.empty?
  abort("Sorry, we need a token to proceed. Please try again.")
end

# Asks user for export path, repo owner, repo, and branches info if not provided in options.
if repo_owner.nil? || repo_owner.empty?
  repo_owner = prompt "Repo owner (repository url is 'repo_owner/repo'): "
end
if repo.nil? || repo.empty?
  repo = prompt "Repo (repository url is 'repo_owner/repo'): "
end
if export_CSV_path.nil? || export_CSV_path.empty?
  export_CSV_path = prompt "Path to export CSV (e.g. ~/Desktop): "
end
if branch_1.nil? || branch_1.empty?
  branch_1 = prompt "From branch: "
end
if branch_2.nil? || branch_2.empty?
  branch_2 = prompt "To branch: "
end

commits = get_commits_between_two_branches(repo_owner, repo, branch_1, branch_2, access_token)
export_commits_to_CSV(commits, repo_owner, repo, access_token, pull_request_regex_by_field, export_CSV_path)

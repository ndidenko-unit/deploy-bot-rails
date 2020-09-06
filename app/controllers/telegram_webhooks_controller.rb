require 'httparty'
require 'pry'

class TelegramWebhooksController < Telegram::Bot::UpdatesController

  FEEDEL_STG_URL = "https://feedel-stg.flippback.com/debug/current_version"
  FEEDEL_PROD_URL = "https://feedel.flippback.com/debug/current_version"
  BUILDER_STG_URL = "https://feedel-csv-builder-stg.flippback.com/debug/current_version"
  BUILDER_PROD_URL = "https://feedel-csv-builder.flippback.com/debug/current_version"

  def start!(*)
    $threads = []
    $threads << Thread.new do

      respond_with :message, text: t('.hi')
      parse_references
      loop do
        begin
          check_feedel_stg("feedel-stg")
          check_feedel_prod("feedel-prod")
          check_builder_stg("feedel-csv-builder-stg")
          check_builder_prod("feedel-csv-builder-prod")
          # respond_with :message, text: @_payload['text']
          # binding.pry
        rescue
          next
        end
      end

    end
  end

  def stop!(*)
    $threads.each { |thread| Thread.kill(thread) }
    respond_with :message, text: t('.bye')
  end

  def ping!(*)
    respond_with :message, text: 'OK'
  end

  def parse_references
    @feedel_stg = HTTParty.get(FEEDEL_STG_URL)
    @feedel_prod = HTTParty.get(FEEDEL_PROD_URL)
    @builder_stg = HTTParty.get(BUILDER_STG_URL)
    @builder_prod = HTTParty.get(BUILDER_PROD_URL)
    respond_with :message, text: 'FEEDEL(STG) current branch: ' + @feedel_stg["current_branch"].first.to_s
    respond_with :message, text: 'FEEDEL(PROD) current branch: ' + @feedel_prod["current_branch"].first.to_s
    respond_with :message, text: 'BUILDER(STG) current branch: ' + @builder_stg["current_branch"].first.to_s
    respond_with :message, text: 'BUILDER(PROD) current branch: ' + @builder_prod["current_branch"].first.to_s
  rescue
    respond_with :message, text: 'Parsing error. Pls, restart me'
  end

  def check_feedel_stg(name)
    @retry_count = 0
    page = parse_page(FEEDEL_STG_URL)
    while page['current_commit'].nil?
      page = retry_not_available(FEEDEL_STG_URL)
    end
    if @feedel_stg['current_commit'][0] != page['current_commit'][0]
      @feedel_stg = msg_new_deploy(page, name)
    end
  end

  def check_feedel_prod(name)
    @retry_count = 0
    page = parse_page(FEEDEL_PROD_URL)
    while page['current_commit'].nil?
      page = retry_not_available(FEEDEL_PROD_URL)
    end
    if @feedel_prod['current_commit'][0] != page['current_commit'][0]
      @feedel_prod = msg_new_deploy(page, name)
    end
  end

  def check_builder_stg(name)
    @retry_count = 0
    page = parse_page(BUILDER_STG_URL)
    while page['current_commit'].nil?
      page = retry_not_available(BUILDER_STG_URL)
    end
    if @builder_stg['current_commit'][0] != page['current_commit'][0]
      @builder_stg = msg_new_deploy(page, name)
    end
  end

  def check_builder_prod(name)
    @retry_count = 0
    page = parse_page(BUILDER_PROD_URL)
    while page['current_commit'].nil?
      page = retry_not_available(BUILDER_PROD_URL)
    end
    if @builder_prod['current_commit'][0] != page['current_commit'][0]
      @builder_prod = msg_new_deploy(page, name)
    end
  end

private

  def msg_new_deploy(parsed_page, name)
    str = "New deploy for #{name}\n
New current branch: #{parsed_page["current_branch"][0]}
#{parsed_page["current_commit"][1].split[0]} #{parsed_page["current_commit"][1].split[1]}
#{parsed_page["current_commit"][2]}
commit: #{parsed_page["current_commit"][3]}
https://github.com/wishabi/#{name.gsub('-stg', '').gsub('-prod', '')}/commit/#{parsed_page["current_commit"][0].split[1]}"
    respond_with :message, text: str
    sleep(5)
    parsed_page
  rescue => error
    puts error
    parsed_page
  end

  def retry_not_available(url)
    @retry_count += 1
    if @retry_count > 2
      text = "#{url} not available #{Time.now}"
      respond_with :message, text: text
    end
    sleep(20)
    HTTParty.get(url)
  rescue
     {}
  end

  def parse_page(url)
    sleep(5)
    HTTParty.get(url)
  rescue
    {}
  end

end

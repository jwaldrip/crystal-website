require "./sponsors"

module OpenCollective
  class API
    def initialize(@team : String)
      @client = HTTP::Client.new("opencollective.com", tls: true)
    end

    def members
      response = @client.get("/#{@team}/members/all.json").body

      begin
        # JSON.parse(response)
        Array(Member).from_json(response)
      rescue ex : JSON::ParseException
        puts "Error trying to parse OpenCollective JSON Response from /#{@team}/members/all.json"
        puts response
        raise ex
      end
    end
  end

  class Member
    include JSON::Serializable

    property name : String
    property type : String
    property role : String
    property isActive : Bool
    property totalAmountDonated : Float64
    property lastTransactionAmount : Float64
    property twitter : String?
    property github : String?
    property website : String?
    property image : String?

    @[JSON::Field(converter: Time::Format.new("%Y-%m-%d %H:%M"))]
    property createdAt : Time
  end
end

team = "crystal-lang"
opencollective = OpenCollective::API.new(team)
sponsors = SponsorsBuilder.new

opencollective.members.each do |member|
  next unless member.role == "BACKER"
  next unless member.isActive
  # organizations that provides gift cards to backers seems
  # to appear with lastTransactionAmount == 0
  # but with totalAmountDonated > 0
  next unless member.lastTransactionAmount > 0
  next if member.name == "incognito"

  url = member.website || member.twitter || member.github
  logo = member.image
  amount = member.lastTransactionAmount
  all_time = member.totalAmountDonated
  sponsors.add Sponsor.new(member.name, url, logo, amount, all_time, nil, member.createdAt, nil)
end

File.open("#{__DIR__}/../_data/opencollective.json", "w") do |file|
  sponsors.save(file)
end

# encoding: UTF-8
require 'rubygems'
require 'test/unit'
require 'fileutils'
require File.expand_path(File.dirname(__FILE__) + "/../lib/calendar_helper")

require 'flexmock/test_unit'

# require 'action_controller'
# require 'action_controller/assertions'
# require 'active_support/inflector'

class CalendarHelperTest < Test::Unit::TestCase

  # include Inflector
  # include ActionController::Assertions::SelectorAssertions
  include CalendarHelper


  def test_with_output
    output = []
    %w(calendar_with_defaults calendar_for_this_month calendar_with_next_and_previous).each do |methodname|
      output << "<h2>#{methodname}</h2>\n" +  send(methodname.to_sym) + "\n\n"
    end
    write_sample "sample.html", output
  end

  def test_simple
    assert_match %r{August}, calendar_with_defaults
  end

  def test_required_fields
    # Year and month are required
    assert_raises(ArgumentError) {
      calendar
    }
    assert_raises(ArgumentError) {
      calendar :year => 1
    }
    assert_raises(ArgumentError) {
      calendar :month => 1
    }
  end

  def test_default_css_classes
    { :table_class => "calendar",
      :month_name_class => "monthName",
      :day_name_class => "dayName",
      :day_class => "day",
      :other_month_class => "otherMonth"
    }.each do |key, value|
      assert_correct_css_class_for_default value
    end
  end

  def test_custom_css_classes
    # Uses the key name as the CSS class name
    [:table_class, :month_name_class, :day_name_class, :day_class, :other_month_class].each do |key|
      assert_correct_css_class_for_key key.to_s, key
    end
  end

  def test_abbrev
    assert_match %r{>Mon<}, calendar_with_defaults()
    assert_match %r{>Monday<}, calendar_with_defaults(:abbrev => false)
  end

  def test_block
    # Even days are special
    assert_match %r{class="special_day"[^>]*>2<}, calendar(:year => 2006, :month => 8) { |d|
      if d.mday % 2 == 0
        [d.mday, {:class => 'special_day'}]
      end
    }
  end

  def test_first_day_of_week
    assert_match %r{<tr class="dayName">\s*<th [^>]*scope="col"><abbr title="Sunday">Sun}, calendar_with_defaults
    # testing that if the abbrev and contracted version are the same, there should be no abbreviation.
    assert_match %r{<tr class="dayName">\s*<th [^>]*scope="col">Sunday}, calendar_with_defaults(:abbrev => false)
    assert_match %r{<tr class="dayName">\s*<th [^>]*scope="col"><abbr title="Monday">Mon}, calendar_with_defaults(:first_day_of_week => 1)
  end

  def test_today_is_in_calendar
    todays_day = Date.today.day
    assert_match %r{class="day.+today"[^>]*>#{todays_day}<}, calendar_for_this_month
  end

  def test_should_not_show_today
    todays_day = Date.today.day
    assert_no_match %r{today}, calendar_for_this_month(:show_today => false)
  end

  # HACK Tried to use assert_select, but it's not made for free-standing
  #      HTML parsing.
  def test_should_have_two_tr_tags_in_the_thead
    # TODO Use a validating service to make sure the rendered HTML is valid
    html = calendar_with_defaults
    assert_match %r{<thead><tr>.*</tr><tr.*</tr></thead>}, html
  end

  def test_table_summary_defaults_to_calendar_period
    html = calendar_with_defaults(:year => 1967, :month => 4)
    assert_match %r{<table [^>]*summary="Calendar for April 1967"}, html
  end

  def test_custom_summary_attribute
    html = calendar_with_defaults(:summary => 'TEST SUMMARY')
    assert_match %r{<table [^>]*summary="TEST SUMMARY">}, html
  end

  def test_table_id_defaults_calendar_year_single_digit_month
    html = calendar_with_defaults(:year => 1967, :month => 4)
    assert_match %r{<table [^>]*id="calendar-1967-04"}, html
  end

  def test_table_id_defaults_calendar_year_double_digit_month
    html = calendar_with_defaults(:year => 1967, :month => 12)
    assert_match %r{<table [^>]*id="calendar-1967-12"}, html
  end

  def test_custom_table_id
    html = calendar_with_defaults(:year => 1967, :month => 4, :table_id => 'test-the-id')
    assert_match %r{<table [^>]*id="test-the-id"}, html
  end

  def test_th_id_defaults_calendar_year_month_dow
    html = calendar_with_defaults(:year => 1967, :month => 4)
    assert_match %r{<tr class=\"dayName\"><th [^>]*id=\"calendar-1967-04-sun\"}, html
  end

  def test_each_td_is_associated_with_appriopriate_th
    html = calendar_with_defaults(:year => 2011, :month => 8)
    assert_match %r{<td [^>]*headers=\"calendar-2011-08-sun\"[^>]*>31</td>}, html
    assert_match %r{<td [^>]*headers=\"calendar-2011-08-mon\"[^>]*>1</td>}, html
  end

  def test_week_number_iso8601
    html = calendar_with_defaults(:year => 2011, :month => 1, :week_number_format => :iso8601, :show_week_numbers => true, :first_day_of_week => 1)
    [52,1,2,3,4,5].each { |cw| assert_match %r{<td class=\"weekNumber\">#{cw}</td>}, html }
  end

  def test_week_number_us_canada
    html = calendar_with_defaults(:year => 2011, :month => 1, :week_number_format => :us_canada, :show_week_numbers => true)
    [1,2,3,4,5,6].each { |cw| assert_match %r{<td class=\"weekNumber\">#{cw}</td>}, html }
  end

  def test_non_english_language
    # mock I18n.t to simulate internationalized setting
    CalendarHelper.const_set :I18n, Class.new {
      def self.t(key)
        if key == "date.day_names"
          ["Ned??le", "Pond??l??", "??ter??", "St??eda", "??tvrtek", "P??tek", "Sobota"]
        elsif key == "date.abbr_day_names"
          ["Ne", "Po", "??t", "St", "??t", "P??", "So"]
        elsif key == "date.month_names"
          ["", "Leden", "??nor", "B??ezen", "Duben", "Kv??ten", "??erven", "??ervenec", "Srpen", "Z??????", "????jen", "Listopad", "Prosinec"]
        end
      end
    }

    html = calendar_with_defaults(:year => 2012, :month => 4)

    # unmock I18n.t again
    CalendarHelper.send(:remove_const, :I18n)

    # make sure all the labels are in english and don't use i18n abbreviation (Ned??le)
    assert_no_match %r(calendar-2012-04-ned), html
    assert_equal 6, html.scan("calendar-2012-04-sun").size # 6 = 5 + header
  end


  private

  def assert_correct_css_class_for_key(css_class, key)
    assert_match %r{class="#{css_class}"}, calendar_with_defaults(key => css_class)
  end

  def assert_correct_css_class_for_default(css_class)
    assert_match %r{class="#{css_class}"}, calendar_with_defaults
  end

  def calendar_with_defaults(options={})
    options = { :year => 2006, :month => 8 }.merge options
    calendar options
  end

  def calendar_for_this_month(options={})
    options = { :year => Time.now.year, :month => Time.now.month}.merge options
    calendar options
  end

  def calendar_with_next_and_previous
    calendar_for_this_month({
      :previous_month_text => "PREVIOUS",
      :next_month_text => "NEXT"
    })
  end

  def write_sample(filename, content)
    FileUtils.mkdir_p "test/output"
    File.open("test/output/#{filename}", 'w') do |f|
      f.write %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html><head><title>Stylesheet Tester</title><link href="../../generators/calendar_styles/templates/grey/style.css" media="screen" rel="Stylesheet" type="text/css" /></head><body>)
      f.write content
      f.write %(</body></html>)
    end
  end

end

require 'sinatra'
require 'uri'

require 'rubygems'
require 'mechanize'
require 'builder/xmlmarkup'

get '/' do
  'cookpad2xml on heroku'
end

get '/search/:word' do
  content_type 'xml'
  xml = Builder::XmlMarkup.new
  xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
  xml.c2x_response('status' => 'ok') do
    agent = Mechanize.new
    agent.get "http://cookpad.com/%E3%83%AC%E3%82%B7%E3%83%94/#{URI.encode(params[:word])}"
    agent.page.search('//div[@class="recipe-preview"]').each do |recipe|
      xml.recipe do
        img = recipe.at('./div[contains(@class, "recipe-image")]//img')
        if img
          xml.image img.attributes['src']
        end
        text = recipe.at('./div[contains(@class, "recipe-text")]')
        xml.title text.at('./span[1]').inner_text.strip
        xml.description text.at('./div[contains(@class, "recipe_description")]').inner_text.strip
        xml.url text.at('.//a[1]')['href']
      end
    end
  end
end

get '/recipe/:id' do
  content_type 'xml'
  xml = Builder::XmlMarkup.new
  xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
  xml.c2x_response('status' => 'ok') do
    agent = Mechanize.new
    agent.get "http://cookpad.com/recipe/#{params[:id]}"
    xml.title agent.page.at('//h1[contains(@class, "recipe-title")]').inner_text.strip
    image = agent.page.at('//img[@class="photo"]')
    xml.image image.attributes['src'] if image
    description = agent.page.at('//div[@id="description"]/text()')
    xml.description description.inner_text.strip if description
    servings_for = agent.page.at('//span[@class="servings_for"]')
    xml.ingredients('servings_for' => servings_for ? servings_for.inner_text.strip : nil) do
      name, quantity = nil, nil
      agent.page.search('//div[@id="ingredients_list"]//div').each do |div|
        name = (name or div.at('.//div[@class="ingredient_name"]'))
        quantity = (quantity or div.at('.//div[@class="ingredient_quantity"]'))
        if name and quantity
          xml.ingredient do
            xml.name name.inner_text.strip
            xml.quantity quantity.inner_text.strip
          end
          name = nil
          quantity = nil
        end
      end
    end
    xml.steps do
      agent.page.search('//div[@id="steps"]//div[@class="step" or @class="step_last"]/dl').each do |dl|
        xml.step do
          xml.number dl.at('h3').inner_text.strip
          img = dl.at('.//img[@alt="写真"]')
          if img
            xml.image img.attributes['src']
          end
          xml.instruction dl.at('./dd[@class="instruction"]/p').inner_text.strip
        end
      end
    end
    advice = agent.page.at('//div[@id="advice"]')
    xml.advice advice.inner_text.strip if advice
  end
end

chai = require 'chai'
{env} = require 'jsdom'
jquery = require 'jquery'
{evaluate} = require '../src/crawler'

chai.should()

describe 'crawler', ->
  describe 'evaluate', ->
    it 'should eval and give back data according to expression', (done) ->
      env HTML, (err, window) ->
        $ = jquery window
        data = evaluate
          'content': ($) ->
            $(".container .content p").text()
        , $
        data.should.eql
          'content': 'sth useful'
        done()

HTML = '''
<div>
  <div class="container">
    <div class="content">
      <p>sth useful</p>
    </div>
  </div>
</div>
'''

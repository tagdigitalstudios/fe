# Question
# - An individual question element
# - children: TextField, ChoiceField, DateField, FileField

# :kind         - 'TextField', 'ChoiceField', 'DateField' for single table inheritance (STI)
# :label        - label for the question, such as "First name"
# :style        - essay|phone|email|numeric|currency|simple, selectbox|radio, checkbox, my|mdy
# :required     - is this question itself required or optional?
# :content      - choices (one per line) for choice field

module Fe
  class Question < Element
    include ActionView::RecordIdentifier # dom_id
    has_many :conditions,
             :class_name => "Condition",
             :foreign_key => "toggle_id",
             :dependent => :nullify

    has_many :dependents,
             :class_name => "Condition",
             :foreign_key => "trigger_id",
             :dependent => :nullify

    has_many :sheet_answers,
             :class_name => "Answer",
             :foreign_key => "question_id",
             :dependent => :destroy

    belongs_to :related_question_sheet,
               :class_name => "QuestionSheet",
               :foreign_key => "related_question_sheet_id"

    # validates_inclusion_of :required, :in => [false, true]

    validates_format_of :slug, :with => /\A[a-z_][a-z0-9_]*\z/,
                        :allow_nil => true, :if => Proc.new { |q| !q.slug.blank? },
                        :message => 'may only contain lowercase letters, digits and underscores; and cannot begin with a digit.' # enforcing lowercase because javascript is case-sensitive
    validates_length_of :slug, :in => 4..36,
                        :allow_nil => true, :if => Proc.new { |q| !q.slug.blank? }
    validates_uniqueness_of :slug,
                            :allow_nil => true, :if => Proc.new { |q| !q.slug.blank? },
                            :message => 'must be unique.'

    # a question has one response per AnswerSheet (that is, an instance of a user filling out the question)
    # generally the response is a single answer
    # however, "Choose Many" (checkbox) questions have multiple answers in a single response

    attr_accessor :answers

    # @answers = nil            # one or more answers in response to this question
    # @mark_for_destroy = nil   # when something is unchecked, there are less answers to the question than before


    # a question is disabled if there is a condition, and that condition evaluates to false
    # could set multiple conditions to influence this question, in which case all must be met
    # def active?
    #   # find first condition that doesn't pass (nil if all pass)
    #   self.conditions.find(:all).find { |c| !c.evaluate? }.nil?  # true if all pass
    # end

    # def conditions_attributes=(new_conditions)
    #   conditions.collect(&:destroy)
    #   conditions.reload
    #   (0..(new_conditions.length - 1)).each do |i|
    #     i = i.to_s
    #     expression = new_conditions[i]["expression"]
    #     trigger_id = new_conditions[i]["trigger_id"].to_i
    #     unless expression.blank? || !page.questions.collect(&:id).include?(trigger_id) || conditions.collect(&:trigger_id).include?(trigger_id)
    #       conditions.create(:question_sheet_id => question_sheet_id, :trigger_id => trigger_id,
    #                         :expression => expression, :toggle_page_id => page_id,
    #                         :toggle_id => self.id)
    #     end
    #   end
    # end

    # element view provides the element label with required indicator
    def default_label?
      true
    end

    def locked?(params, answer_sheet, presenter)
      return true unless ['fe/answer_pages', 'fe/reference_sheets'].include?(params['controller']) && params['action'] == 'edit'
      if self.object_name == 'person.current_address' && ['address1','address2','city','zip','email','state','country'].include?(self.attribute_name)
        # Billing Address
        return false
      elsif self.object_name == 'person.emergency_address' && ['address1','address2','city','zip','email','state','country','contactName','homePhone','workPhone'].include?(self.attribute_name)
        # Emergency Contact
        return false
      elsif self.label == 'Relationship To You' || self.style == "country" || (self.style == "email" && self.label == "Confirm Email")
        # Relationship & Country & Email Address
        return false
      else
        return answer_sheet.frozen? && !presenter.reference?
      end
    end

    # css class names for javascript-based validation
    def validation_class(answer_sheet = nil)
      if required?(answer_sheet)
        ' required '
      else
        ''
      end
    end

    # just in case something slips through client-side validation?
    # def valid_response?
    #   if self.required? && !self.has_response? then
    #     false
    #   else
    #     # other validations
    #     true
    #   end
    # end

    # just in case something slips through client-side validation?
    # def valid_response_for_answer_sheet?(answers)
    #    return true if !self.required?
    #    answer  = answers.detect {|a| a.question_id == self.id}
    #    return answer && answer.value.present?
    #    # raise answer.inspect
    #  end

    # shortcut to return first answer
    def response(answer_sheet)
      responses(answer_sheet).first.to_s
    end

    def display_response(answer_sheet)
      r = responses(answer_sheet)
      if r.blank?
        ""
      else
        r.join(", ")
      end
    end

    def responses(answer_sheet)
      return [] unless answer_sheet

      # try to find answer from external object
      if !object_name.blank? and !attribute_name.blank?
        obj = %w(answer_sheet application reference).include?(object_name) ? answer_sheet : eval("answer_sheet." + object_name)
        if obj.nil? or eval("obj." + attribute_name + ".nil?")
          []
        else
          [eval("obj." + attribute_name)]
        end
      else
        #answer_sheet.answers_by_question[id] || []
        Fe::Answer.where(:answer_sheet_id => answer_sheet.id, :question_id => self.id).to_a
      end
    end

    # set answers from posted response
    def set_response(values, answer_sheet)
      puts "\nQuestion::set_response entered, values: #{values} answer_sheet: #{answer_sheet}"
      values = Array.wrap(values)
      if !object_name.blank? and !attribute_name.blank?
        puts "\nQuestion::set_response object_name or attribute_name is set; object_name=#{object_name} attribute_name=#{attribute_name}"
        # if eval("answer_sheet." + object_name).present?
        object = %w(answer_sheet application).include?(object_name) ? answer_sheet : eval("answer_sheet." + object_name)
        unless object.present?
          if object_name.include?('.')
            objects = object_name.split('.')
            object = eval("answer_sheet." + objects[0..-2].join('.') + ".create_" + objects.last)
            eval("answer_sheet." + objects[0..-2].join('.')).reload
          end
        end
        unless responses(answer_sheet) == values
          value = values.first
          if self.is_a?(Fe::DateField) && value.present?
            begin
              value = Date.strptime(value, (I18n.t 'date.formats.default'))
            rescue
              raise "invalid date - " + value.inspect
            end
          end
          object.update_attribute(attribute_name, value)
        end
        # else
        #   raise object_name.inspect + ' == ' + attribute_name.inspect
        # end
      else
        puts "\nQuestion::set_response no object_name or attribute_name set"
        puts "\nQuestion::set_response @answers at this point: #{@answers.inspect}"

        @answers ||= []
        @mark_for_destroy ||= []
        # go through existing answers (in reverse order, as we delete)
        (@answers.length - 1).downto(0) do |index|
          # reject: skip over responses that are unchanged
          unless values.reject! {|value| value == @answers[index]}
            # remove any answers that don't match the posted values
            @mark_for_destroy << @answers[index]   # destroy from database later
            @answers.delete_at(index)
          end
        end

        puts "\nQuestion::set_response after existing answers check; @answers at this point: #{@answers.inspect}"

        # insert any new answers
        for value in values
          if @mark_for_destroy.empty?
            puts "\nQuestion::set_response new answer create (but not saved to db yet)"
            answer = Fe::Answer.new(:question_id => self.id)
          else
            # re-use marked answers (an update vs. a delete+insert)
            puts "\nQuestion::set_response re-use marked answers"
            answer = @mark_for_destroy.pop
          end
          answer.set(value)
          @answers << answer
        end
        puts "\nQuestion::set_response after insert any new answers section; @answers at this point: #{@answers.inspect}"
      end
    end

    def save_file(answer_sheet, file)
      @answers.collect(&:destroy) if @answers
      Fe::Answer.create!(:question_id => self.id, :answer_sheet_id => answer_sheet.id, :attachment => file)
    end

    # save this question's @answers to database
    def save_response(answer_sheet)
      puts "Fe::Question#save_response answer_sheet @answers=#{@answers.inspect}"
      unless @answers.nil?
        for answer in @answers
          puts "Fe::Question#save_response answer.class.name=#{answer.class.name}"
          if answer.is_a?(Fe::Answer)
            puts "Fe::Question#save_response saving here"
            answer.answer_sheet_id = answer_sheet.id
            binding.pry
            answer.save!
          end
        end
      end

      # remove others
      unless @mark_for_destroy.nil?
        for answer in @mark_for_destroy
          answer.destroy
        end
        @mark_for_destroy.clear
      end
    rescue TypeError
      raise answer.inspect
    end

    # has any sort of non-empty response?
    def has_response?(answer_sheet = nil)
      if answer_sheet.present?
        answers = responses(answer_sheet)
      else
        answers = Fe::Answer.where(:question_id => self.id)
      end
      return false if answers.length == 0
      answers.each do |answer|   # loop through Answers
        value = answer.is_a?(Fe::Answer) ? answer.value : answer
        return true if (value.is_a?(FalseClass) && value === false) || value.present?
      end
      false
    end

    def required?(answer_sheet = nil)
      super
    end

  end
end

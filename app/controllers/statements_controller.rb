class StatementsController < ApplicationController
  before_action :login_required, only: [:new, :create, :create_and_vote]
  before_action :admin_required, only: [:edit, :update, :destroy]
  before_action :find_statement, only: [:show, :destroy, :update, :edit, :occupations, :educated_at]
  before_action :find_related_statements, only: :show
  before_action :set_percentage_and_count, only: [:show, :occupations, :educated_at]
  before_action :redirect_to_statement_url, only: :show
  before_action :set_back_url_to_current_page, only: [:show, :index]

  def quick_create
    @statement = Statement.new(content: params[:question])
    @statement.tag_list = "Others"
    if @statement.save
      if current_user
        unless current_user.email.present?
          current_user.email = params[:email]
          current_user.save
        end
      else
        Individual.find_or_create(email: params[:email])
      end
      LogMailer.log_email("@#{params[:email]} has created '#{@statement.content}'").deliver
      redirect_to @statement
    else
      flash[:error] = @statement.errors.messages[:content].first
      render template: "static_pages/home"
    end
  end

  def create_and_vote # from new_question_path & from user profiles
    @statement = find_statement_by_content || Statement.new(content: params[:content], individual: current_user)
    LogMailer.log_email("@#{current_user.try(:visible_name)} has created '#{@statement.content}' and voted from profile").deliver
    if @statement.save
      Agreement.create(
        statement: @statement,
        individual_id: params[:individual_id] || current_user.id,
        reason: params[:reason],
        url: params[:url],
        extent: ((params[:commit] == "She/he agrees") ? 100 : 0))
      redirect_to(get_and_delete_back_url || new_path)
    else
      flash[:error] = @statement.errors.full_messages.first
      redirect_to new_path
    end
  end

  # GET /statements
  # GET /statements.json
  def index
    @statements = Statement.select("statements.id, statements.content, statements.hashed_id, count(agreements.id) as agreements_count").joins("left join agreements on statements.id=agreements.statement_id").group("statements.id").order("agreements_count DESC, statements.created_at ASC")

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @statements }
    end
  end

  # GET /statements/1
  # GET /statements/1.json
  def show
    if params[:c] == "Others"
      @agreements_in_favor = @statement.agreements_in_favor(order: params[:order], filter_by: :non_categorized, profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at], page: params[:page])
      @agreements_against = @statement.agreements_against(order: params[:order], filter_by: :non_categorized, profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at], page: params[:page])
    else
      category_id = ReasonCategory.find_by_name(params[:c]).try(:id)
      @agreements_in_favor = @statement.agreements_in_favor(order: params[:order], category_id: category_id, profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at], page: params[:page])
      @agreements_against = @statement.agreements_against(order: params[:order], category_id: category_id, profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at], page: params[:page])
    end
    @comment = Comment.new
    @comments = {}
    @statement.comments.each{|comment| @comments[comment.individual.id] = comment}

    @categories = ReasonCategory.all
    @professions = Profession.all
    @admin = admin?
    if session[:added_voter].present?
      @just_added_voter = Individual.find_by_hashed_id(session[:added_voter])
    end
    @shortened_url_without_params = Rails.env.test? ? request.url : Shortener.new(full_url: request.base_url + request.path, object: @statement).get

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @statement }
    end
  end

  # GET /statements/new
  # GET /statements/new.json
  def new
    @statement = Statement.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @statement }
    end
  end

  # GET /statements/1/edit
  def edit
  end

  # POST /statements
  # POST /statements.json
  def create
    @statement = Statement.new(params.require(:statement).permit(:content))

    if @statement.save
      LogMailer.log_email("New statement: #{@statement.content} created by @#{current_user.try(:twitter)}, email: #{current_user.try(:email)}, ip: #{request.remote_ip}").deliver
      redirect_to @statement, notice: 'Statement was successfully created'
    else
      render action: "new"
    end
  end

  # PUT /statements/1
  # PUT /statements/1.json
  def update
    respond_to do |format|
      if @statement.update_attributes(params.require(:statement).permit(:content, :tag_list))
        format.html { redirect_to(get_and_delete_back_url || statements_path, notice: 'Statement was successfully updated.') }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @statement.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /statements/1
  # DELETE /statements/1.json
  def destroy
    @statement.destroy

    respond_to do |format|
      format.html { redirect_to statements_url }
      format.json { head :no_content }
    end
  end

  def occupations
    @min_count = (params[:min] || 1).to_i
    @occupations_count = OccupationsTable.new(statement: @statement, min_count: @min_count).table
  end

  def educated_at
    @min_count = (params[:min] || 1).to_i
    @schools_count = SchoolsTable.new(statement: @statement, min_count: @min_count).table
  end

  private

  def find_statement
    @statement = Statement.find_by_hashed_id(params[:id].split("-").last)
  end

  def redirect_to_statement_url
    redirect_to statement_path(@statement) if params[:id] != @statement.to_param
  end

  def set_percentage_and_count
    supporters_count = @statement.supporters_count(profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at])
    detractors_count = @statement.detractors_count(profession: params[:profession], occupation: params[:occupation], educated_at: params[:educated_at])
    @agreements_count = supporters_count + detractors_count
    @percentage_in_favor = (supporters_count * 100.0 / @agreements_count).round if @agreements_count > 0
  end

  def find_related_statements
    tags = @statement.tag_list
    tags.delete("top")
    tag = tags.first
    tag = "top" if tag.nil? || tag == "none"
    @related_statements = Statement.where.not(id: @statement.id).tagged_with(tag).order(created_at: :desc).limit(6)
  end

  def find_statement_by_content
    Statement.where('lower(content) = ?', params[:content]).first
  end
end

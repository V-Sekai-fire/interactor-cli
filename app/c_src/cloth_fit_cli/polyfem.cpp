#include <fine.hpp>

// PolyFEM includes
#include <polyfem/garment/optimize.hpp>
#include <polyfem/garment/coordinate_system.hpp>
#include <polyfem/solver/GarmentNLProblem.hpp>
#include <polyfem/solver/forms/ContactForm.hpp>
#include <polyfem/solver/forms/garment_forms/GarmentForm.hpp>
#include <polyfem/solver/forms/garment_forms/GarmentALForm.hpp>
#include <polyfem/solver/forms/garment_forms/CurveConstraintForm.hpp>
#include <polyfem/solver/forms/garment_forms/CurveCenterTargetForm.hpp>
#include <polyfem/solver/forms/garment_forms/FitForm.hpp>
#include <polyfem/solver/ALSolver.hpp>
#include <polyfem/utils/JSONUtils.hpp>
#include <polyfem/utils/Logger.hpp>
#include <polyfem/mesh/MeshUtils.hpp>
#include <polyfem/io/OBJWriter.hpp>
#include <polyfem/io/MatrixIO.hpp>
#ifdef POLYFEM_WITH_USD
#include "loader.hpp" // dlopen the cloth_fit_usd bridge (src/usd_bridge)
#endif

#include <igl/edges.h>
#include <igl/read_triangle_mesh.h>
#include <igl/write_triangle_mesh.h>
#include <igl/readOBJ.h>
#include <igl/writeOBJ.h>

#include <polysolve/nonlinear/Solver.hpp>
#include <ipc/ipc.hpp>

#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include <string>
#include <cstring>
#include <memory>
#include <fstream>
#include <sstream>
#include <vector>
#include <iostream>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <chrono>

using json = nlohmann::json;
using namespace polyfem;
using namespace polyfem::solver;
using namespace polyfem::mesh;

// Helpers for building the {:ok, _} / {:error, reason} result tuples that the
// Elixir API (ClothFitCli.PolyFEM) pattern-matches on.
namespace {
    fine::Term ok_string(ErlNifEnv* env, const std::string& value) {
        return fine::encode(env, fine::Ok<std::string>(value));
    }
    fine::Term ok_bool(ErlNifEnv* env, bool value) {
        return fine::encode(env, fine::Ok<bool>(value));
    }
    fine::Term error(ErlNifEnv* env, const std::string& reason) {
        return fine::encode(env, fine::Error<std::string>(reason));
    }
}

// Simple JSON implementation for basic operations (fallback)
namespace simple_json {
    std::string escape_string(const std::string& str) {
        std::string result;
        for (char c : str) {
            switch (c) {
                case '"': result += "\\\""; break;
                case '\\': result += "\\\\"; break;
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                default: result += c; break;
            }
        }
        return result;
    }
}

// Simple 3D vector class for basic operations
struct Vec3 {
    double x, y, z;
    Vec3() : x(0), y(0), z(0) {}
    Vec3(double x_, double y_, double z_) : x(x_), y(y_), z(z_) {}
    Vec3 operator-(const Vec3& other) const { return Vec3(x - other.x, y - other.y, z - other.z); }
    Vec3 cross(const Vec3& other) const {
        return Vec3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x);
    }
    double norm() const { return std::sqrt(x*x + y*y + z*z); }
};

// Simple mesh structure for basic validation
struct SimpleMesh {
    std::vector<Vec3> vertices;
    std::vector<std::vector<int>> faces;

    bool load_obj(const std::string& filename) {
        std::ifstream file(filename);
        if (!file.is_open()) {
            return false;
        }

        std::string line;
        while (std::getline(file, line)) {
            std::istringstream iss(line);
            std::string prefix;
            iss >> prefix;

            if (prefix == "v") {
                double x, y, z;
                if (iss >> x >> y >> z) {
                    vertices.emplace_back(x, y, z);
                }
            } else if (prefix == "f") {
                std::vector<int> face;
                std::string vertex_data;
                while (iss >> vertex_data) {
                    size_t slash_pos = vertex_data.find('/');
                    std::string vertex_index_str = vertex_data.substr(0, slash_pos);
                    int vertex_index = std::stoi(vertex_index_str) - 1; // OBJ is 1-indexed
                    face.push_back(vertex_index);
                }
                if (face.size() >= 3) {
                    faces.push_back(face);
                }
            }
        }

        return !vertices.empty() && !faces.empty();
    }

    Vec3 get_bbox_min() const {
        if (vertices.empty()) return Vec3();
        Vec3 min_pt = vertices[0];
        for (const auto& v : vertices) {
            min_pt.x = std::min(min_pt.x, v.x);
            min_pt.y = std::min(min_pt.y, v.y);
            min_pt.z = std::min(min_pt.z, v.z);
        }
        return min_pt;
    }

    Vec3 get_bbox_max() const {
        if (vertices.empty()) return Vec3();
        Vec3 max_pt = vertices[0];
        for (const auto& v : vertices) {
            max_pt.x = std::max(max_pt.x, v.x);
            max_pt.y = std::max(max_pt.y, v.y);
            max_pt.z = std::max(max_pt.z, v.z);
        }
        return max_pt;
    }

    double calculate_surface_area() const {
        double total_area = 0.0;
        for (const auto& face : faces) {
            if (face.size() >= 3) {
                Vec3 v0 = vertices[face[0]];
                Vec3 v1 = vertices[face[1]];
                Vec3 v2 = vertices[face[2]];
                Vec3 cross_product = (v1 - v0).cross(v2 - v0);
                total_area += 0.5 * cross_product.norm();
            }
        }
        return total_area;
    }
};

fine::Term simulate(ErlNifEnv* env, std::string config, std::string output_path) {
    // Input validation
    if (output_path.empty()) {
        return error(env, "Output path cannot be empty");
    }

    try {
        auto start_time = std::chrono::high_resolution_clock::now();

        // Extract JSON configuration from payload
        if (config.empty()) {
            return error(env, "Empty configuration payload");
        }
        std::string config_json = config;

        // Parse JSON configuration
        json in_args;
        try {
            in_args = json::parse(config_json);
        } catch (const json::parse_error& e) {
            std::string error_msg = "JSON parse error: " + std::string(e.what());
            return error(env, error_msg);
        }

        // Create output directory
        std::string output_dir(output_path);
        std::filesystem::create_directories(output_dir);

        // Set up logging to be less verbose for NIF usage
        spdlog::set_level(spdlog::level::warn);
        polyfem::logger().set_level(spdlog::level::warn);

        // Initialize PolyFEM with the configuration
        json args;
        try {
            args = polyfem::init(in_args, false);
        } catch (const std::exception& e) {
            std::string error_msg = "PolyFEM initialization error: " + std::string(e.what());
            return error(env, error_msg);
        }

        // Create GarmentSolver instance
        GarmentSolver gstate;
        gstate.out_folder = output_dir;
        gstate.out_format = args.value("/output/format"_json_pointer, std::string("obj"));
#ifdef POLYFEM_WITH_USD
        cfusd_loader::load_from_env(); // dlopen the USD bridge (no-op if already loaded)
#endif

        // Extract paths from configuration
        const std::string avatar_mesh_path = args["avatar_mesh_path"];
        const std::string garment_mesh_path = args["garment_mesh_path"];
        const std::string source_skeleton_path = args["source_skeleton_path"];
        const std::string target_skeleton_path = args["target_skeleton_path"];
        const std::string avatar_skin_weights_path = args["avatar_skin_weights_path"];
        const bool self_collision = args["contact"]["enabled"];

        // Validate input files exist
        if (!std::filesystem::exists(avatar_mesh_path)) {
            return error(env, "Invalid avatar mesh path: " + avatar_mesh_path);
        }
        if (!std::filesystem::exists(garment_mesh_path)) {
            return error(env, "Invalid garment mesh path: " + garment_mesh_path);
        }
        if (!std::filesystem::exists(source_skeleton_path)) {
            return error(env, "Invalid source skeleton path: " + source_skeleton_path);
        }
        if (!std::filesystem::exists(target_skeleton_path)) {
            return error(env, "Invalid target skeleton path: " + target_skeleton_path);
        }

        // Load meshes and prepare simulation
        gstate.read_meshes(avatar_mesh_path, source_skeleton_path, target_skeleton_path, avatar_skin_weights_path);
        gstate.load_garment_mesh(garment_mesh_path, args["no_fit_spec_path"]);

        // Normalize inputs from their declared authoring convention into the
        // canonical Godot frame (+Y up, +Z front, right-handed). Everything
        // downstream — solve, collision, and USD/OBJ output — is then Godot/
        // glTF-ready. Default input convention is Blender (+Z up, -Y front, RH);
        // override via setup.json "input_coordinate_system".
        {
            const polyfem::garment::Convention input_cs = polyfem::garment::parse_convention(
                args.contains("input_coordinate_system") ? args["input_coordinate_system"] : json::object(),
                polyfem::garment::blender_default());
            const Eigen::Matrix3d M = polyfem::garment::to_canonical(input_cs);
            if (!M.isIdentity(1e-9)) {
                polyfem::garment::apply_to_rows(M, gstate.avatar_v);
                polyfem::garment::apply_to_rows(M, gstate.garment.v);
                polyfem::garment::apply_to_rows(M, gstate.skeleton_v);
                polyfem::garment::apply_to_rows(M, gstate.target_skeleton_v);
                polyfem::garment::apply_to_normals(M, gstate.avatar_VN);
                if (M.determinant() < 0) {
                    // Handedness flip: reverse winding so normals stay outward.
                    polyfem::garment::flip_winding(gstate.avatar_f);
                    polyfem::garment::flip_winding(gstate.garment.f);
                }
            }
        }

        gstate.normalize_meshes();
        gstate.project_avatar_to_skeleton();

        // Save initial meshes (OBJ or USD per out_format)
        polyfem::write_mesh_with_groups(output_dir + "/target_avatar", gstate.out_format, polyfem::eigen_to_obj_data(gstate.avatar_v, gstate.avatar_f));
        polyfem::write_mesh_with_groups(output_dir + "/projected_avatar", gstate.out_format, polyfem::eigen_to_obj_data(gstate.skinny_avatar_v, gstate.nc_avatar_f));
        write_edge_mesh(output_dir + "/target_skeleton.obj", gstate.target_skeleton_v, gstate.target_skeleton_b);
        write_edge_mesh(output_dir + "/source_skeleton.obj", gstate.skeleton_v, gstate.skeleton_b);

        // Set up collision mesh
        Eigen::MatrixXi collision_triangles(gstate.nc_avatar_f.rows() + gstate.n_garment_faces(), gstate.garment.f.cols());
        collision_triangles << gstate.nc_avatar_f, gstate.garment.f.array() + gstate.nc_avatar_v.rows();
        Eigen::MatrixXi collision_edges;
        igl::edges(collision_triangles, collision_edges);

        Eigen::MatrixXd collision_vertices(gstate.nc_avatar_v.rows() + gstate.n_garment_vertices(), gstate.garment.v.cols());
        collision_vertices << gstate.skinny_avatar_v, gstate.garment.v;

        ipc::CollisionMesh collision_mesh;
        collision_mesh = ipc::CollisionMesh(collision_vertices, collision_edges, collision_triangles);

        const int n_avatar_verts = gstate.nc_avatar_v.rows();
        collision_mesh.can_collide = [n_avatar_verts, self_collision](size_t vi, size_t vj) {
            if (self_collision)
                return vi >= n_avatar_verts || vj >= n_avatar_verts;
            else
                return (vi >= n_avatar_verts && vj < n_avatar_verts) || (vi < n_avatar_verts && vj >= n_avatar_verts);
        };

        // Check for initial intersections
        gstate.check_intersections(collision_mesh, collision_vertices);

        // Set up boundary curves and targets
        auto curves = boundary_curves(collision_triangles.bottomRows(gstate.n_garment_faces()));
        const Eigen::MatrixXd source_curve_centers = extract_curve_center_targets(collision_vertices, curves, gstate.skeleton_v, gstate.skeleton_b, gstate.skeleton_v);
        const Eigen::MatrixXd target_curve_centers = extract_curve_center_targets(collision_vertices, curves, gstate.skeleton_v, gstate.skeleton_b, gstate.target_skeleton_v);

        const Eigen::MatrixXd initial_garment_v = gstate.garment.v;
        int save_id = 0;
        const int total_steps = args["incremental_steps"];
        const int stride = args["output"]["skip_frame"];

        // Set up persistent forms
        std::vector<std::shared_ptr<Form>> persistent_forms;
        std::vector<std::shared_ptr<Form>> persistent_full_forms;
        std::shared_ptr<CurveSizeForm> curve_size_form;

        // Similarity form
        auto similarity_form = std::make_shared<SimilarityForm>(collision_vertices, collision_triangles.bottomRows(gstate.n_garment_faces()));
        similarity_form->set_weight(args["similarity_penalty_weight"]);
        persistent_forms.push_back(similarity_form);

        // Optional forms based on configuration
        if (args["curvature_penalty_weight"] > 0) {
            auto curvature_form = std::make_shared<CurveCurvatureForm>(collision_vertices, curves);
            curvature_form->set_weight(args["curvature_penalty_weight"]);
            persistent_forms.push_back(curvature_form);
        }

        if (args["twist_penalty_weight"] > 0) {
            auto twist_form = std::make_shared<CurveTorsionForm>(collision_vertices, curves);
            twist_form->set_weight(args["twist_penalty_weight"]);
            persistent_forms.push_back(twist_form);
        }

        if (args["symmetry_weight"] > 0) {
            auto sym_form = std::make_shared<SymmetryForm>(collision_vertices, curves);
            sym_form->set_weight(args["symmetry_weight"]);
            if (sym_form->enabled())
                persistent_forms.push_back(sym_form);
        }

        if (args["curve_size_weight"] > 0) {
            curve_size_form = std::make_shared<CurveSizeForm>(collision_vertices, curves);
            curve_size_form->disable();
            curve_size_form->set_weight(args["curve_size_weight"]);
            persistent_forms.push_back(curve_size_form);
        }

        // Contact form
        const double dhat = args["contact"]["dhat"];
        std::shared_ptr<ContactForm> contact_form = std::make_shared<ContactForm>(
            collision_mesh, dhat, 1, false, false, false, false,
            args["solver"]["contact"]["CCD"]["broad_phase"],
            args["solver"]["contact"]["CCD"]["tolerance"],
            args["solver"]["contact"]["CCD"]["max_iterations"]);
        contact_form->set_weight(1);
        contact_form->set_barrier_stiffness(args["solver"]["contact"]["barrier_stiffness"]);
        contact_form->save_ccd_debug_meshes = false;
        persistent_forms.push_back(contact_form);

        // Curve target form
        const auto tmp_curves = boundary_curves(gstate.garment.f);
        auto center_target_form = std::make_shared<CurveTargetForm>(
            initial_garment_v, tmp_curves, gstate.skeleton_v, gstate.target_skeleton_v,
            gstate.skeleton_b, args["is_skirt"], args["curve_center_target_automatic_bone_generation"]);
        center_target_form->set_weight(args["curve_center_target_weight"]);
        persistent_full_forms.push_back(center_target_form);

        // Main simulation loop
        Eigen::MatrixXd sol = Eigen::MatrixXd::Zero(1 + initial_garment_v.size(), 1);

        for (int substep = 0; substep < total_steps; ++substep) {
            const double next_alpha = (substep + 1) / (double)total_steps;

            // Continuation
            const Eigen::MatrixXd next_avatar_v = (gstate.nc_avatar_v - gstate.skinny_avatar_v) * next_alpha + gstate.skinny_avatar_v;

            std::vector<std::shared_ptr<Form>> forms = persistent_forms;
            std::shared_ptr<PointPenaltyForm> pen_form;
            std::shared_ptr<PointLagrangianForm> lagr_form;
            std::shared_ptr<FitForm<4>> fit_form;

            // Set up step-specific forms
            std::vector<int> indices(gstate.nc_avatar_v.size());
            for (int i = 0; i < indices.size(); i++)
                indices[i] = i;
            pen_form = std::make_shared<PointPenaltyForm>(utils::flatten(next_avatar_v - gstate.skinny_avatar_v), indices);
            forms.push_back(pen_form);

            lagr_form = std::make_shared<PointLagrangianForm>(utils::flatten(next_avatar_v - gstate.skinny_avatar_v), indices);
            forms.push_back(lagr_form);

            fit_form = std::make_shared<FitForm<4>>(collision_vertices, collision_triangles.bottomRows(gstate.n_garment_faces()),
                                                   gstate.avatar_v, gstate.avatar_f, args["voxel_size"], gstate.not_fit_fids, output_dir);
            fit_form->disable();
            fit_form->set_weight(args["fit_weight"]);
            forms.push_back(fit_form);

            if (args["curve_size_weight"] > 0)
                curve_size_form->disable();

            // Create and solve NL problem
            GarmentNLProblem nl_problem(1 + initial_garment_v.size(), utils::flatten(gstate.nc_avatar_v - gstate.skinny_avatar_v), forms, persistent_full_forms);
            nl_problem.set_target_value(next_alpha);

            nl_problem.line_search_begin(sol, sol);
            if (!std::isfinite(nl_problem.value(sol)) || !nl_problem.is_step_valid(sol, sol) || !nl_problem.is_step_collision_free(sol, sol)) {
                return error(env, "Failed to apply boundary conditions!");
            }

            // Set up solvers
            std::shared_ptr<polysolve::nonlinear::Solver> nl_solver = polysolve::nonlinear::Solver::create(
                args["solver"]["augmented_lagrangian"]["nonlinear"], args["solver"]["linear"], 1., polyfem::logger());

            double initial_weight = args["solver"]["augmented_lagrangian"]["initial_weight"];
            const double scaling = args["solver"]["augmented_lagrangian"]["scaling"];
            const double max_weight = args["solver"]["augmented_lagrangian"]["max_weight"].get<double>();

            ALSolver<GarmentNLProblem, PointLagrangianForm, PointPenaltyForm> al_solver(
                lagr_form, pen_form, initial_weight, scaling, max_weight,
                args["solver"]["augmented_lagrangian"]["eta"],
                args["solver"]["augmented_lagrangian"]["error_threshold"],
                [](const Eigen::VectorXd &x) {});

            // Set up save callback
            nl_problem.post_step_call_back = [&](const Eigen::VectorXd &sol) {
                if (save_id % stride == 0)
                    gstate.save_result(output_dir, save_id / stride, nl_problem, collision_vertices, collision_triangles, sol);
                ++save_id;
            };

            // Solve AL problem
            al_solver.solve_al(nl_solver, nl_problem, sol);

            // Enable fit form and solve reduced problem
            fit_form->enable();
            if (args["curve_size_weight"] > 0 && substep == total_steps - 1)
                curve_size_form->enable();

            nl_solver = polysolve::nonlinear::Solver::create(args["solver"]["nonlinear"], args["solver"]["linear"], 1., polyfem::logger());
            al_solver.solve_reduced(nl_solver, nl_problem, sol);
        }

        // Calculate simulation time
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        double simulation_time = duration.count() / 1000.0;

        // Create result JSON
        json result;
        result["status"] = "completed";
        result["output_path"] = output_dir;
        result["config_size"] = config.size();
        result["simulation_time"] = simulation_time;
        result["iterations"] = total_steps;
        result["message"] = "Garment retargeting succeeded!";
        result["avatar_vertices"] = gstate.nc_avatar_v.rows();
        result["garment_vertices"] = gstate.n_garment_vertices();
        result["total_vertices"] = gstate.nc_avatar_v.rows() + gstate.n_garment_vertices();

        std::string result_str = result.dump();
        return ok_string(env, result_str);

    } catch (const std::exception& e) {
        std::string error_msg = "Simulation error: " + std::string(e.what());
        return error(env, error_msg);
    }
}

fine::Term validate_garment_mesh(ErlNifEnv* env, std::string mesh_path) {
    // Input validation
    if (mesh_path.empty()) {
        return error(env, "Invalid mesh path");
    }

    try {
        // Load mesh using simple OBJ reader
        SimpleMesh mesh;
        if (!mesh.load_obj(mesh_path)) {
            return error(env, "Failed to read mesh file");
        }

        // Basic validation checks for garment meshes
        bool is_valid = true;
        std::string validation_errors;

        // Check if mesh has vertices and faces
        if (mesh.vertices.empty()) {
            is_valid = false;
            validation_errors += "No vertices found. ";
        }

        if (mesh.faces.empty()) {
            is_valid = false;
            validation_errors += "No faces found. ";
        }

        // Check for reasonable mesh size (garments should have some complexity)
        if (mesh.vertices.size() < 10) {
            is_valid = false;
            validation_errors += "Too few vertices for a garment mesh. ";
        }

        if (mesh.faces.size() < 10) {
            is_valid = false;
            validation_errors += "Too few faces for a garment mesh. ";
        }

        // Check for valid face indices
        for (const auto& face : mesh.faces) {
            for (int vertex_idx : face) {
                if (vertex_idx < 0 || vertex_idx >= static_cast<int>(mesh.vertices.size())) {
                    is_valid = false;
                    validation_errors += "Invalid face index found. ";
                    break;
                }
            }
            if (!is_valid) break;
        }

        // Check for degenerate faces (faces with zero area)
        int degenerate_count = 0;
        for (const auto& face : mesh.faces) {
            if (face.size() >= 3) {
                Vec3 v0 = mesh.vertices[face[0]];
                Vec3 v1 = mesh.vertices[face[1]];
                Vec3 v2 = mesh.vertices[face[2]];
                double area = 0.5 * (v1 - v0).cross(v2 - v0).norm();
                if (area < 1e-12) {
                    degenerate_count++;
                }
            }
        }

        if (degenerate_count > static_cast<int>(mesh.faces.size()) * 0.1) { // More than 10% degenerate faces
            is_valid = false;
            validation_errors += "Too many degenerate faces. ";
        }

        // Check bounding box (garment should have reasonable dimensions)
        Vec3 bbox_min = mesh.get_bbox_min();
        Vec3 bbox_max = mesh.get_bbox_max();
        Vec3 bbox_size = bbox_max - bbox_min;

        double max_dimension = std::max({bbox_size.x, bbox_size.y, bbox_size.z});
        if (max_dimension < 1e-6) {
            is_valid = false;
            validation_errors += "Mesh has zero or near-zero dimensions. ";
        }

        if (!is_valid) {
            return error(env, validation_errors);
        }

        return ok_bool(env, is_valid);

    } catch (const std::exception& e) {
        std::string error_msg = "Error validating garment mesh: " + std::string(e.what());
        return error(env, error_msg);
    }
}

fine::Term validate_avatar_mesh(ErlNifEnv* env, std::string mesh_path) {
    // Input validation
    if (mesh_path.empty()) {
        return error(env, "Invalid mesh path");
    }

    try {
        // Load mesh using simple OBJ reader
        SimpleMesh mesh;
        if (!mesh.load_obj(mesh_path)) {
            return error(env, "Failed to read mesh file");
        }

        // Basic validation checks for avatar meshes
        bool is_valid = true;
        std::string validation_errors;

        // Check if mesh has vertices and faces
        if (mesh.vertices.empty()) {
            is_valid = false;
            validation_errors += "No vertices found. ";
        }

        if (mesh.faces.empty()) {
            is_valid = false;
            validation_errors += "No faces found. ";
        }

        // Avatar meshes should be more complex than garment meshes
        if (mesh.vertices.size() < 100) {
            is_valid = false;
            validation_errors += "Too few vertices for an avatar mesh. ";
        }

        if (mesh.faces.size() < 100) {
            is_valid = false;
            validation_errors += "Too few faces for an avatar mesh. ";
        }

        // Check for valid face indices
        for (const auto& face : mesh.faces) {
            for (int vertex_idx : face) {
                if (vertex_idx < 0 || vertex_idx >= static_cast<int>(mesh.vertices.size())) {
                    is_valid = false;
                    validation_errors += "Invalid face index found. ";
                    break;
                }
            }
            if (!is_valid) break;
        }

        // Check bounding box and proportions (avatar should be humanoid-like)
        Vec3 bbox_min = mesh.get_bbox_min();
        Vec3 bbox_max = mesh.get_bbox_max();
        Vec3 bbox_size = bbox_max - bbox_min;

        double max_dimension = std::max({bbox_size.x, bbox_size.y, bbox_size.z});
        if (max_dimension < 1e-6) {
            is_valid = false;
            validation_errors += "Mesh has zero or near-zero dimensions. ";
        }

        // Proportion sanity check against the default input convention (Blender
        // Z-up): a humanoid's up axis should be its tallest extent. Checking the
        // declared up axis (not a hard-coded Y) avoids rejecting Z-up assets that
        // retarget fine, while still catching meshes authored in the wrong frame.
        // See src/polyfem/garment/coordinate_system.hpp.
        const double ext[3] = {bbox_size.x, bbox_size.y, bbox_size.z};
        const int up = polyfem::garment::up_axis_index(polyfem::garment::blender_default());
        const double up_extent = ext[up];
        const double max_horizontal = std::max(ext[(up + 1) % 3], ext[(up + 2) % 3]);
        const double height_to_width = up_extent / std::max(max_horizontal, 1e-9);
        if (height_to_width < 0.2 || height_to_width > 20.0) {
            is_valid = false;
            validation_errors += "Extreme aspect ratio for avatar mesh (the up axis is not the tallest extent — is the mesh in the declared input convention?). ";
        }

        // Check for degenerate faces
        int degenerate_count = 0;
        for (const auto& face : mesh.faces) {
            if (face.size() >= 3) {
                Vec3 v0 = mesh.vertices[face[0]];
                Vec3 v1 = mesh.vertices[face[1]];
                Vec3 v2 = mesh.vertices[face[2]];
                double area = 0.5 * (v1 - v0).cross(v2 - v0).norm();
                if (area < 1e-12) {
                    degenerate_count++;
                }
            }
        }

        if (degenerate_count > static_cast<int>(mesh.faces.size()) * 0.05) { // More than 5% degenerate faces
            is_valid = false;
            validation_errors += "Too many degenerate faces. ";
        }

        // Check mesh complexity (avatars should have reasonable detail)
        if (mesh.vertices.size() > 100000) {
            // Very high poly count - might cause performance issues
            // For now we'll allow it, but could add warnings
        }

        if (!is_valid) {
            return error(env, validation_errors);
        }

        return ok_bool(env, is_valid);

    } catch (const std::exception& e) {
        std::string error_msg = "Error validating avatar mesh: " + std::string(e.what());
        return error(env, error_msg);
    }
}

fine::Term load_garment_info(ErlNifEnv* env, std::string garment_path) {
    // Input validation
    if (garment_path.empty()) {
        return error(env, "Invalid garment path");
    }

    try {
        // Load garment mesh using simple OBJ reader
        SimpleMesh mesh;
        if (!mesh.load_obj(garment_path)) {
            return error(env, "Failed to read garment mesh file");
        }

        // Calculate mesh statistics
        int vertex_count = static_cast<int>(mesh.vertices.size());
        int face_count = static_cast<int>(mesh.faces.size());

        // Calculate bounding box
        Vec3 bbox_min = mesh.get_bbox_min();
        Vec3 bbox_max = mesh.get_bbox_max();
        Vec3 bbox_size = bbox_max - bbox_min;

        // Create JSON response with mesh information using nlohmann::json
        json info_json;
        info_json["vertex_count"] = vertex_count;
        info_json["face_count"] = face_count;
        info_json["bounding_box"]["min"] = {bbox_min.x, bbox_min.y, bbox_min.z};
        info_json["bounding_box"]["max"] = {bbox_max.x, bbox_max.y, bbox_max.z};
        info_json["bounding_box"]["size"] = {bbox_size.x, bbox_size.y, bbox_size.z};
        info_json["mesh_type"] = "garment";
        info_json["file_path"] = garment_path;

        std::string info_str = info_json.dump();
        return ok_string(env, info_str);

    } catch (const std::exception& e) {
        std::string error_msg = "Error loading garment info: " + std::string(e.what());
        return error(env, error_msg);
    }
}

fine::Term load_avatar_info(ErlNifEnv* env, std::string avatar_path) {
    // Input validation
    if (avatar_path.empty()) {
        return error(env, "Invalid avatar path");
    }

    try {
        // Load avatar mesh using simple OBJ reader
        SimpleMesh mesh;
        if (!mesh.load_obj(avatar_path)) {
            return error(env, "Failed to read avatar mesh file");
        }

        // Calculate mesh statistics
        int vertex_count = static_cast<int>(mesh.vertices.size());
        int face_count = static_cast<int>(mesh.faces.size());

        // Calculate bounding box
        Vec3 bbox_min = mesh.get_bbox_min();
        Vec3 bbox_max = mesh.get_bbox_max();
        Vec3 bbox_size = bbox_max - bbox_min;

        // Calculate additional avatar-specific metrics
        double surface_area = mesh.calculate_surface_area();

        // Check if this looks like a valid avatar mesh (basic heuristics)
        bool is_likely_avatar = (vertex_count > 1000 && face_count > 1000 &&
                                bbox_size.y > bbox_size.x && bbox_size.y > bbox_size.z);

        // Create JSON response with mesh information using nlohmann::json
        json info_json;
        info_json["vertex_count"] = vertex_count;
        info_json["face_count"] = face_count;
        info_json["surface_area"] = surface_area;
        info_json["bounding_box"]["min"] = {bbox_min.x, bbox_min.y, bbox_min.z};
        info_json["bounding_box"]["max"] = {bbox_max.x, bbox_max.y, bbox_max.z};
        info_json["bounding_box"]["size"] = {bbox_size.x, bbox_size.y, bbox_size.z};
        info_json["mesh_type"] = "avatar";
        info_json["is_likely_avatar"] = is_likely_avatar;
        info_json["file_path"] = avatar_path;

        std::string info_str = info_json.dump();
        return ok_string(env, info_str);

    } catch (const std::exception& e) {
        std::string error_msg = "Error loading avatar info: " + std::string(e.what());
        return error(env, error_msg);
    }
}

// NIF registration (Fine). Arity is derived automatically; the second argument
// is the scheduling flag. The solver is long-running and CPU-bound, so it runs
// on a dirty scheduler to avoid blocking the BEAM.
FINE_NIF(simulate, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(validate_garment_mesh, 0);
FINE_NIF(validate_avatar_mesh, 0);
FINE_NIF(load_garment_info, 0);
FINE_NIF(load_avatar_info, 0);

FINE_INIT("Elixir.PolyFem");

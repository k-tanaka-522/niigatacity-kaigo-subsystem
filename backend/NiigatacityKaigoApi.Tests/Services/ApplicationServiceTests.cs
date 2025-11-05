using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using NiigatacityKaigoApi.DTOs;
using NiigatacityKaigoApi.Models;
using NiigatacityKaigoApi.Repositories;
using NiigatacityKaigoApi.Services;
using Xunit;

namespace NiigatacityKaigoApi.Tests.Services;

public class ApplicationServiceTests
{
    private readonly Mock<IApplicationRepository> _mockRepository;
    private readonly Mock<ILogger<ApplicationService>> _mockLogger;
    private readonly ApplicationService _service;

    public ApplicationServiceTests()
    {
        _mockRepository = new Mock<IApplicationRepository>();
        _mockLogger = new Mock<ILogger<ApplicationService>>();
        _service = new ApplicationService(_mockRepository.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task GetByIdAsync_ExistingId_ReturnsApplication()
    {
        // Arrange
        var applicationId = Guid.NewGuid();
        var application = new CareApplication
        {
            Id = applicationId,
            ApplicationNumber = "APP-20250101-12345",
            SubjectId = Guid.NewGuid(),
            ApplicationType = "新規",
            ApplicationDate = DateTime.Now,
            Status = "申請中",
            CreatedBy = Guid.NewGuid()
        };

        _mockRepository.Setup(r => r.GetByIdAsync(applicationId))
            .ReturnsAsync(application);

        // Act
        var result = await _service.GetByIdAsync(applicationId);

        // Assert
        result.Should().NotBeNull();
        result!.ApplicationNumber.Should().Be("APP-20250101-12345");
    }

    [Fact]
    public async Task CreateAsync_ValidData_ReturnsCreatedApplication()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var dto = new CreateCareApplicationDto
        {
            SubjectId = Guid.NewGuid(),
            ApplicationType = "新規",
            ApplicationDate = DateTime.Now
        };

        _mockRepository.Setup(r => r.CreateAsync(It.IsAny<CareApplication>()))
            .ReturnsAsync((CareApplication app) => app);

        // Act
        var result = await _service.CreateAsync(dto, userId);

        // Assert
        result.Should().NotBeNull();
        result.ApplicationType.Should().Be("新規");
        result.Status.Should().Be("申請中");
    }
}
